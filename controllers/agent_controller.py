# controllers/agent_controller.py
import json
import time
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel
import os
from fastapi import Request
from db import get_connection
from services.ai_agent import (
    generate_car_voice, generate_ai_diagnostic,
    compute_weekly_score, analyze_danger_pattern, save_diagnostic,
    get_notif_preferences, update_notif_preferences, get_last_pannes,
    OIL_CHANGE_KM_INTERVAL, MAINTENANCE_INTERVALS, get_km_since_repair,
    is_oil_change_due_by_date, generate_daily_report, send_daily_reports,
    _get_doc_alerts_for_driver,
)
from models.notif_preferences import NotifPreferences, NotifPreferencesUpdate, DEFAULT_REMINDER_THRESHOLDS
from services.alert_messages import get_alert_info, CRITICAL_CODES
from services.notification_worker import _send_fcm
from groq import Groq
from anthropic import Anthropic
from services.auth_service import decode_token
from dependencies import security

router   = APIRouter()
IS_PROD  = os.getenv("ENV", "dev") == "prod"
groq_client      = Groq(api_key=os.getenv("GROQ_API_KEY"))
anthropic_client = Anthropic()


def get_current_driver(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    if credentials:
        try:
            payload = decode_token(credentials.credentials)
            cin = payload.get("cin")
            if cin:
                return str(cin)
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")


class ChatMessage(BaseModel):
    message: str
    history: Optional[List[dict]] = []

class GeofenceCreate(BaseModel):
    name: str
    zone_type: str = "circle"
    center_lat: Optional[float] = None
    center_lon: Optional[float] = None
    radius_km: Optional[float] = None
    polygon_coords: Optional[list] = None
    vehicule_matricule: str

class ReminderCreate(BaseModel):
    title: str
    description: str
    remind_at: datetime
    repeat_days: Optional[int] = None

class ReportHourUpdate(BaseModel):
    hour: int

# AlertThreshold v1 (Groq version)
class AlertThresholdV1(BaseModel):
    max_speed_kmh:       Optional[int]   = 120
    min_oil_pressure:    Optional[float] = 2.5
    min_battery_voltage: Optional[float] = 12.0
    max_engine_temp:     Optional[int]   = 100
    idle_max_minutes:    Optional[int]   = 30

# AlertThreshold v2 (Anthropic version)
class AlertThreshold(BaseModel):
    max_speed_kmh:    Optional[int] = 120
    max_engine_temp:  Optional[int] = 100
    max_car_temp:     Optional[int] = 80
    idle_max_minutes: Optional[int] = 5


FALLBACK_SET = {
    'Diagnostic en cours de génération par l\'IA...',
    'Analyse en cours',
    'En cours d\'évaluation',
    'Consultez votre mécanicien',
    'Consulter un mécanicien',
    'Analyse des données en cours',
    'Consultez un mécanicien qualifié',
    'Risque inconnu — consultez un professionnel',
    'Risque de dommages si non traité',
}

MAX_RETRIES   = 5
RETRY_DELAY_S = 3


def _get_label_from_code(code: int) -> str:
    return get_alert_info(code)[0]


def _get_driver_context(cin: str) -> str:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT v.mark, v.model, v.matricule
            FROM vehicule v
            JOIN compte_driver d ON d.vehicule_id = v.matricule
            WHERE d.cin = %s LIMIT 1
        """, (cin,))
        veh = cursor.fetchone()

        cursor.execute("""
            SELECT added_info AS code, date FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info IS NOT NULL AND added_info != 0
            ORDER BY date DESC LIMIT 10
        """, (cin,))
        events = cursor.fetchall()

        cursor.execute("""
            SELECT score_today, report_date FROM daily_reports
            WHERE driver_id = %s ORDER BY report_date DESC LIMIT 1
        """, (cin,))
        score_row = cursor.fetchone()

        ctx = {
            "vehicule":        f"{veh['mark']} {veh['model']} {veh['matricule']}" if veh else "Inconnu",
            "score_semaine":   score_row["score_today"] if score_row else "Non calculé",
            "derniers_events": [
                f"{_get_label_from_code(ev['code'])} ({str(ev['date'])[:16]})"
                for ev in events
            ][:5],
        }
        return json.dumps(ctx, ensure_ascii=False, default=str)
    finally:
        conn.close()


CHAT_SYSTEM = """
Tu es un assistant intelligent intégré dans une application de gestion de flotte et de conduite.
Tu aides le conducteur à comprendre l'état de son véhicule, ses statistiques de conduite,
et tu réponds à ses questions techniques.
Sois concis, utile, et bienveillant. Réponds toujours en français. Maximum 3 paragraphes.
"""


# ── Chat ──────────────────────────────────────────────────────────────────────

@router.post("/api/agent/chat")
def agent_chat(body: ChatMessage, cin: str = Depends(get_current_driver)):
    context         = _get_driver_context(cin)
    system_with_ctx = CHAT_SYSTEM + f"\n\nContexte actuel du conducteur :\n{context}"
    messages        = list(body.history or [])
    messages.append({"role": "user", "content": body.message})
    try:
        response = anthropic_client.messages.create(
            model="claude-opus-4-5",
            max_tokens=600,
            system=system_with_ctx,
            messages=messages,
        )
        reply = response.content[0].text
        return {
            "reply":   reply,
            "history": messages + [{"role": "assistant", "content": reply}],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur agent: {e}")


# ── Diagnostics ───────────────────────────────────────────────────────────────

@router.get("/api/agent/diagnostics")
def get_diagnostics(cin: str = Depends(get_current_driver), limit: int = 20):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.*, e.date AS event_date
            FROM ai_diagnostics d
            JOIN events e ON e.id = d.event_id
            WHERE d.driver_id = %s
            ORDER BY e.date DESC LIMIT %s
        """, (cin, limit))
        return {"diagnostics": [dict(r) for r in cursor.fetchall()]}
    finally:
        conn.close()


@router.get("/api/agent/diagnostics/{event_id}")
def get_diagnostic_detail(event_id: int, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        NON_PANNE_CODES = {17, 18}

        def _is_complete(d: dict) -> bool:
            for k in ('diagnosis', 'cause', 'action_required'):
                v = (d.get(k) or '').strip()
                if not v or v in FALLBACK_SET:
                    return False
            return True

        def _fetch_event():
            cursor.execute("""
                SELECT e.added_info AS code, e.date, v.mark, v.model, v.matricule
                FROM events e
                JOIN compte_driver d ON d.cin = e.driver_id
                LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
                WHERE e.id = %s AND e.driver_id = %s
            """, (event_id, cin))
            return cursor.fetchone()

        cursor.execute(
            "SELECT * FROM ai_diagnostics WHERE event_id = %s AND driver_id = %s LIMIT 1",
            (event_id, cin)
        )
        row = cursor.fetchone()

        if row:
            diag = dict(row)
            if _is_complete(diag):
                if not diag.get("car_voice"):
                    ev = _fetch_event()
                    if ev:
                        diag["car_voice"] = generate_car_voice(ev["code"], {"vehicule": f"{ev['mark']} {ev['model']}"})
                return diag

        ev = _fetch_event()
        if not ev:
            raise HTTPException(status_code=404, detail="Event introuvable")
        if ev["code"] in NON_PANNE_CODES:
            raise HTTPException(status_code=400, detail="Pas de diagnostic pour ce type d'événement")

        diag = None
        for attempt in range(MAX_RETRIES):
            if attempt > 0:
                print(f">>> [DIAG-CTRL] Retry {attempt}/{MAX_RETRIES-1} pour event {event_id}...")
                time.sleep(RETRY_DELAY_S)

            diag = generate_ai_diagnostic(ev["code"], {
                "mark":      ev["mark"],
                "model":     ev["model"],
                "matricule": ev["matricule"],
            })

            if _is_complete(diag):
                save_diagnostic(cursor, conn, event_id, cin, diag)
                print(f">>> [DIAG-CTRL] ✅ Diagnostic complet obtenu en {attempt+1} tentative(s)")
                return diag

            print(f">>> [DIAG-CTRL] Tentative {attempt+1} incomplète → retry")

        if diag:
            save_diagnostic(cursor, conn, event_id, cin, diag)
        return diag or {}

    finally:
        conn.close()


# ── Car Voice ─────────────────────────────────────────────────────────────────

@router.get("/api/agent/car-voice/{event_id}")
def get_car_voice(event_id: int, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT e.added_info AS code, v.mark, v.model
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE e.id = %s AND e.driver_id = %s
        """, (event_id, cin))
        ev = cursor.fetchone()
        if not ev:
            raise HTTPException(status_code=404, detail="Event introuvable")
        voice = generate_car_voice(ev["code"], {"vehicule": f"{ev['mark']} {ev['model']}"})
        return {"event_id": event_id, "car_voice": voice}
    finally:
        conn.close()


# ── Score ─────────────────────────────────────────────────────────────────────

@router.get("/api/agent/score")
def get_current_score(cin: str = Depends(get_current_driver)):
    """
    Retourne le dernier score depuis daily_reports (la seule table persistée
    par _save_driver_score), ou le calcule à la volée si absent.
    """
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT report_json, score_today, report_date
            FROM daily_reports
            WHERE driver_id = %s
            ORDER BY report_date DESC LIMIT 1
        """, (cin,))
        row = cursor.fetchone()
        if not row:
            return compute_weekly_score(cin)

        report = json.loads(row["report_json"]) if row["report_json"] else {}
        return {
            "driver_id":    cin,
            "global_score": row["score_today"],
            "report_date":  str(row["report_date"]),
            "categories": {
                "vitesse":   report.get("score_vitesse"),
                "freinage":  report.get("score_freinage"),
                "vigilance": report.get("score_vigilance"),
                "fatigue":   report.get("score_fatigue"),
                "securite":  report.get("score_securite"),
            },
            "ai_report": report.get("ai_report"),
        }
    finally:
        conn.close()


@router.post("/api/agent/score/compute")
def trigger_score_computation(cin: str = Depends(get_current_driver)):
    return compute_weekly_score(cin)


@router.get("/api/agent/score/history")
def get_score_history(cin: str = Depends(get_current_driver), weeks: int = 8):
   
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT report_date, score_today, report_json
            FROM daily_reports
            WHERE driver_id = %s
            ORDER BY report_date DESC
            LIMIT %s
        """, (cin, weeks))
        history = []
        for r in cursor.fetchall():
            report = json.loads(r["report_json"]) if r["report_json"] else {}
            history.append({
                "week_start":      str(r["report_date"]),
                "global_score":    r["score_today"],
                "score_vitesse":   report.get("score_vitesse"),
                "score_freinage":  report.get("score_freinage"),
                "score_vigilance": report.get("score_vigilance"),
                "score_fatigue":   report.get("score_fatigue"),
                "score_securite":  report.get("score_securite"),
            })
        return {"history": history}
    finally:
        conn.close()


# ── Daily Reports ─────────────────────────────────────────────────────────────

@router.get("/api/agent/daily-report")
def get_daily_report(cin: str = Depends(get_current_driver), date: str = None):
    """
    Retourne le rapport du jour depuis la BD.
    Si absent, le génère via le service et le persiste.
    """
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        report_date = date or str(datetime.now().date())
        cursor.execute("""
            SELECT report_json FROM daily_reports
            WHERE driver_id = %s AND report_date = %s
        """, (cin, report_date))
        row = cursor.fetchone()
        if row:
            return {"report": json.loads(row["report_json"])}

        # Pas encore généré : on délègue au service
        report = generate_daily_report(cin)
        return {"report": report}
    finally:
        conn.close()


@router.post("/api/agent/daily-report/generate")
def force_generate_daily_report(cin: str = Depends(get_current_driver)):
    """Force la re-génération du rapport du jour (écrase l'existant via ON DUPLICATE KEY)."""
    report = generate_daily_report(cin)
    if not report:
        raise HTTPException(status_code=500, detail="Impossible de générer le rapport")
    return {"report": report}


@router.post("/api/agent/daily-reports/send-all")
def trigger_send_daily_reports(cin: str = Depends(get_current_driver)):
    """Déclenche l'envoi des rapports à tous les conducteurs (admin / cron manuel)."""
    send_daily_reports()
    return {"success": True}


@router.get("/api/agent/daily-reports/history")
def get_reports_history(cin: str = Depends(get_current_driver), limit: int = 30):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT report_date, score_today, report_json, created_at
            FROM daily_reports
            WHERE driver_id = %s
            ORDER BY report_date DESC
            LIMIT %s
        """, (cin, limit))
        reports = []
        for r in cursor.fetchall():
            reports.append({
                "report_date": str(r["report_date"]),
                "score_today": r["score_today"],
                "report":      json.loads(r["report_json"]) if r["report_json"] else None,
            })
        return {"reports": reports}
    finally:
        conn.close()


@router.put("/api/agent/report-hour")
def update_report_hour(body: ReportHourUpdate, cin: str = Depends(get_current_driver)):
    if not 0 <= body.hour <= 23:
        raise HTTPException(status_code=400, detail="Heure invalide (0-23)")
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE compte_driver SET report_hour = %s WHERE cin = %s",
            (body.hour, cin)
        )
        conn.commit()
        return {"success": True}
    finally:
        conn.close()


# ── Doc Alerts ────────────────────────────────────────────────────────────────

@router.get("/api/agent/doc-alerts")
def get_doc_alerts(cin: str = Depends(get_current_driver)):
    """Retourne les documents/amendes expirant dans les 7 prochains jours."""
    alerts = _get_doc_alerts_for_driver(cin)
    return {"alerts": alerts}


# ── SAV KM Reminders ──────────────────────────────────────────────────────────

@router.get("/api/agent/sav-reminders")
def get_sav_reminders(cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.vehicule_id, v.date_purchase
            FROM compte_driver d
            JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE d.cin = %s
        """, (cin,))
        veh = cursor.fetchone()
        if not veh:
            return {"reminders": []}

        vehicule_id   = veh["vehicule_id"]
        date_purchase = veh["date_purchase"]

        cursor.execute("""
            SELECT id_sav, maintenance_type, date_reparation
            FROM sav
            WHERE vehicule_id = %s
              AND maintenance_type IS NOT NULL
              AND id_sav = (
                  SELECT MAX(s2.id_sav) FROM sav s2
                  WHERE s2.vehicule_id      = sav.vehicule_id
                    AND s2.maintenance_type = sav.maintenance_type
              )
        """, (vehicule_id,))
        savs = cursor.fetchall()

        reminders = []
        for sav in savs:
            mtype    = sav["maintenance_type"]
            date_rep = sav["date_reparation"]

            if mtype == "Oil Change":
                if is_oil_change_due_by_date(date_rep):
                    reminders.append({
                        "id":               sav["id_sav"],
                        "title":            "Vidange",
                        "description":      "1 an écoulé depuis la dernière vidange !",
                        "remind_at":        str(date_rep),
                        "type":             "reminder",
                        "reminder_type":    "sav_km_reminder",
                        "seuil":            "DÉPASSÉ",
                        "maintenance_type": mtype,
                        "km_parcourus":     "—",
                        "km_interval":      str(OIL_CHANGE_KM_INTERVAL),
                        "km_restants":      "0",
                        "is_urgent":        True,
                        "triggered_by":     "date",
                    })
                    continue
                interval_km = OIL_CHANGE_KM_INTERVAL
            else:
                interval_km = MAINTENANCE_INTERVALS.get(mtype)
                if not interval_km:
                    continue

            km_since = get_km_since_repair(cursor, vehicule_id, date_rep)
            if km_since is None:
                continue

            ratio       = km_since / interval_km
            km_restants = int(interval_km - km_since)

            if ratio < 0.70:
                continue

            if ratio >= 1.0:
                seuil     = "DÉPASSÉ"
                is_urgent = True
                desc      = f"Dépassé de {abs(km_restants)} km !"
            elif ratio >= 0.90:
                seuil     = "URGENT"
                is_urgent = True
                desc      = f"Plus que {km_restants} km avant l'entretien"
            else:
                seuil     = "PRÉVENTIF"
                is_urgent = False
                desc      = f"{int(km_since)}/{interval_km} km parcourus"

            reminders.append({
                "id":               sav["id_sav"],
                "title":            f"Entretien {mtype}",
                "description":      desc,
                "remind_at":        str(sav["date_reparation"]),
                "type":             "reminder",
                "reminder_type":    "sav_km_reminder",
                "seuil":            seuil,
                "maintenance_type": mtype,
                "km_parcourus":     str(int(km_since)),
                "km_interval":      str(interval_km),
                "km_restants":      str(km_restants),
                "is_urgent":        is_urgent,
            })

        return {"reminders": reminders}

    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f">>> [SAV-REMINDERS] ERREUR: {e}")
        return {"reminders": []}
    finally:
        conn.close()


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/api/agent/stats")
def get_vehicle_stats(cin: str = Depends(get_current_driver), days: int = 30):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        since = datetime.now() - timedelta(days=days)
        cursor.execute("""
            SELECT
                COUNT(*) AS total_events,
                SUM(CASE WHEN added_info IN (22,23,24,25) THEN 1 ELSE 0 END) AS conduite_agressive,
                SUM(CASE WHEN added_info IN (1,2,3,30)   THEN 1 ELSE 0 END) AS risques_securite,
                SUM(CASE WHEN added_info IN (9,11,12,14)  THEN 1 ELSE 0 END) AS comportement_conducteur,
                SUM(CASE WHEN added_info IN (32,33,34,35,36,37) THEN 1 ELSE 0 END) AS pannes_mecaniques,
                SUM(CASE WHEN added_info = 17 THEN 1 ELSE 0 END) AS demarrages,
                SUM(CASE WHEN added_info = 18 THEN 1 ELSE 0 END) AS arrets
            FROM events
            WHERE driver_id = %s AND subtype = 11 AND date >= %s
        """, (cin, since))
        stats = dict(cursor.fetchone() or {})

        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS cnt
            FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info IS NOT NULL AND added_info != 0 AND date >= %s
            GROUP BY added_info ORDER BY cnt DESC LIMIT 10
        """, (cin, since))
        top_codes = [
            {"code": r["code"], "label": _get_label_from_code(r["code"]), "count": r["cnt"]}
            for r in cursor.fetchall()
        ]

        cursor.execute("""
            SELECT DATE(date) AS day, COUNT(*) AS cnt
            FROM events
            WHERE driver_id = %s AND subtype = 11 AND date >= %s
            GROUP BY DATE(date) ORDER BY day ASC
        """, (cin, since))
        timeline = [{"day": str(r["day"]), "count": r["cnt"]} for r in cursor.fetchall()]

        return {"period_days": days, "summary": stats, "top_events": top_codes, "timeline": timeline}
    finally:
        conn.close()


# ── Geofences ─────────────────────────────────────────────────────────────────

@router.get("/api/agent/geofences")
def list_geofences(cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT gz.* FROM geofences gz
            JOIN compte_driver d ON d.vehicule_id = gz.vehicule_id
            WHERE d.cin = %s ORDER BY gz.created_at DESC
        """, (cin,))
        return {"geofences": [dict(r) for r in cursor.fetchall()]}
    finally:
        conn.close()


@router.post("/api/agent/geofences")
def create_geofence(body: GeofenceCreate, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT cin FROM compte_driver
            WHERE cin = %s AND vehicule_id = %s LIMIT 1
        """, (cin, body.vehicule_matricule))
        if not cursor.fetchone():
            raise HTTPException(status_code=403, detail="Véhicule non autorisé")

        polygon_json = json.dumps(body.polygon_coords) if body.polygon_coords else None
        cursor.execute("""
            INSERT INTO geofences
                (vehicule_id, name, zone_type, center_lat, center_lon,
                 radius_km, polygon_coords, is_active, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE, NOW())
        """, (
            body.vehicule_matricule, body.name, body.zone_type,
            body.center_lat, body.center_lon, body.radius_km, polygon_json,
        ))
        conn.commit()
        return {"id": cursor.lastrowid, "message": "Zone créée"}
    finally:
        conn.close()


@router.delete("/api/agent/geofences/{geofence_id}")
def delete_geofence(geofence_id: int, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            DELETE gz FROM geofences gz
            JOIN compte_driver d ON d.vehicule_id = gz.vehicule_id
            WHERE gz.id = %s AND d.cin = %s
        """, (geofence_id, cin))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Zone introuvable")
        return {"success": True}
    finally:
        conn.close()


# ── Thresholds v1 (Groq) ──────────────────────────────────────────────────────

@router.get("/api/agent/thresholds/v1")
def get_thresholds_v1(cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM alert_thresholds WHERE driver_id = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        return dict(row) if row else AlertThresholdV1().model_dump()
    finally:
        conn.close()


@router.put("/api/agent/thresholds/v1")
def update_thresholds_v1(body: AlertThresholdV1, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO alert_thresholds
                (driver_id, max_speed_kmh, min_oil_pressure,
                 min_battery_voltage, max_engine_temp, idle_max_minutes, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            ON DUPLICATE KEY UPDATE
                max_speed_kmh       = VALUES(max_speed_kmh),
                min_oil_pressure    = VALUES(min_oil_pressure),
                min_battery_voltage = VALUES(min_battery_voltage),
                max_engine_temp     = VALUES(max_engine_temp),
                idle_max_minutes    = VALUES(idle_max_minutes),
                updated_at          = NOW()
        """, (
            cin, body.max_speed_kmh, body.min_oil_pressure,
            body.min_battery_voltage, body.max_engine_temp, body.idle_max_minutes,
        ))
        conn.commit()
        return {"success": True}
    finally:
        conn.close()


# ── Thresholds v2 (Anthropic) ─────────────────────────────────────────────────

@router.get("/api/agent/thresholds")
def get_thresholds(cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM alert_thresholds WHERE driver_id = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        return dict(row) if row else AlertThreshold().model_dump()
    finally:
        conn.close()


@router.put("/api/agent/thresholds")
def update_thresholds(body: AlertThreshold, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO alert_thresholds
                (driver_id, max_speed_kmh, max_engine_temp, max_car_temp, idle_max_minutes, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
            ON DUPLICATE KEY UPDATE
                max_speed_kmh    = VALUES(max_speed_kmh),
                max_engine_temp  = VALUES(max_engine_temp),
                max_car_temp     = VALUES(max_car_temp),
                idle_max_minutes = VALUES(idle_max_minutes),
                updated_at       = NOW()
        """, (
            cin, body.max_speed_kmh, body.max_engine_temp,
            body.max_car_temp, body.idle_max_minutes,
        ))
        conn.commit()
        return {"success": True}
    finally:
        conn.close()


# ── Reminders ─────────────────────────────────────────────────────────────────

@router.get("/api/agent/reminders")
def list_reminders(cin: str = Depends(get_current_driver)):
    return {"reminders": []}


@router.post("/api/agent/reminders")
def create_reminder(body: ReminderCreate, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO driver_reminders
                (driver_id, title, description, remind_at, repeat_days, is_sent, created_at)
            VALUES (%s, %s, %s, %s, %s, FALSE, NOW())
        """, (cin, body.title, body.description, body.remind_at, body.repeat_days))
        conn.commit()
        return {"id": cursor.lastrowid, "message": "Rappel créé"}
    finally:
        conn.close()


@router.delete("/api/agent/reminders/{reminder_id}")
def delete_reminder(reminder_id: int, cin: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            DELETE FROM driver_reminders WHERE id = %s AND driver_id = %s
        """, (reminder_id, cin))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Rappel introuvable")
        return {"success": True}
    finally:
        conn.close()


# ── Garages ───────────────────────────────────────────────────────────────────

@router.get("/api/agent/garages")
async def find_nearest_garages(
    lat: float,
    lon: float,
    code: Optional[int] = None,
    cin: str = Depends(get_current_driver),
):
    try:
        from services.overpass_service import get_osm_garages
        garages = await get_osm_garages(lat=lat, lon=lon, radius_m=50000, limit=5)

        ai_recommendation = None
        if code and garages:
            label = _get_label_from_code(code)
            garage_list = [
                f"{g['nom']} ({g.get('distance_km', '?')}km) — note: {g.get('rating') or 'N/A'}"
                for g in garages
            ]
            prompt = (
                f"Panne détectée: {label}\n"
                f"Garages disponibles:\n" + "\n".join(garage_list) + "\n"
                "Recommande le garage le plus adapté en 1-2 phrases en français."
            )
            try:
                resp = anthropic_client.messages.create(
                    model="claude-haiku-4-5-20251001",
                    max_tokens=200,
                    messages=[{"role": "user", "content": prompt}],
                )
                ai_recommendation = resp.content[0].text
            except Exception as e:
                print(f">>> Erreur recommandation IA: {e}")
                ai_recommendation = "Contactez le garage le plus proche pour assistance."

        return {
            "garages":           garages,
            "ai_recommendation": ai_recommendation,
            "search_radius_km":  50,
        }
    except Exception as e:
        print(f">>> Erreur recherche garages: {e}")
        return {"garages": [], "ai_recommendation": None, "error": str(e)}


# ── Notif Preferences ─────────────────────────────────────────────────────────

@router.get("/api/agent/notif-preferences")
def get_notif_prefs(cin: str = Depends(get_current_driver)):
    return get_notif_preferences(cin)


@router.put("/api/agent/notif-preferences")
def update_notif_prefs(
    body: NotifPreferencesUpdate,
    cin: str = Depends(get_current_driver),
):
    thresholds = body.reminder_thresholds if body.reminder_thresholds is not None \
                 else [1800, 3600, 86400, 259200, 604800, 1209600]

    ok = update_notif_preferences(
        cin,
        body.notif_preferences.model_dump(),
        thresholds,
    )
    if not ok:
        raise HTTPException(status_code=500, detail="Erreur mise à jour")
    return {"success": True}


# ── Last Pannes ───────────────────────────────────────────────────────────────

@router.get("/api/vehicle/last-pannes")
def last_pannes(cin: str = Depends(get_current_driver)):
    return {"pannes": get_last_pannes(cin)}