# services/chat_service.py
import os
import json
from datetime import datetime, date, timedelta
from dotenv import load_dotenv
from math import radians, sin, cos, sqrt, atan2

load_dotenv()

from groq import Groq
from db import get_connection

_api_key = os.getenv("GROQ_API_KEY")
client = Groq(api_key=_api_key)
print(f"[chat_service] GROQ_API_KEY chargee ({(_api_key or '')[:8]}...)")

EVENT_LABELS = {
    0: "Aucun evenement", 1: "Avertissement collision frontale",
    2: "Avertissement pieton frontal", 3: "Avertissement sortie de voie",
    4: "Pare-chocs virtuel", 9: "Appel telephonique au volant",
    10: "Smoking detecte", 11: "Distraction", 12: "Fatigue detectee",
    14: "Ceinture non attachee", 17: "Allumage ON", 18: "Allumage OFF",
    19: "Mise a jour GPS", 22: "Exces de vitesse", 23: "Acceleration brusque",
    24: "Freinage brusque", 25: "Virage brusque", 29: "Arret moteur prolonge",
    30: "Collision detectee", 31: "Manipulation suspecte", 32: "Batterie faible",
    33: "Batterie morte", 34: "Defaillance alternateur", 35: "Defaut electrique",
    36: "Panne moteur", 37: "Surchauffe moteur", 38: "Rates moteur",
    39: "Calage moteur", 40: "Pression huile faible", 41: "Fuite d'huile",
    42: "Niveau huile critique", 43: "Defaillance transmission",
    44: "Glissement embrayage", 45: "Erreur changement vitesse",
    46: "Defaillance freins", 47: "Defaut ABS", 48: "Usure freins elevee",
    49: "Arret brusque", 50: "Crevaison detectee", 51: "Carburant bas",
    52: "Surchauffe",
}

from services.alert_messages import MECHANICAL_CODES as PANNE_CODES

SEVERITY_EMOJI = {"critical": "🔴", "warning": "🟡", "info": "🟢"}

BAD_DRIVING_CODES = {
    22: ("vitesse",   15), 23: ("vitesse",    8),
    24: ("freinage",   8), 25: ("freinage",   6),
    9:  ("vigilance", 20), 10: ("vigilance", 10),
    11: ("vigilance", 15), 12: ("fatigue",   25),
    14: ("vigilance", 10), 30: ("securite",  30),
}

BAD_DRIVING_LABELS = {
    22: "exces de vitesse", 23: "acceleration brusque",
    24: "freinage brusque",  25: "virage brusque",
    9:  "telephone au volant", 10: "smoking",
    11: "distraction",      12: "fatigue",
    14: "ceinture non attachee", 30: "collision",
}

MAINTENANCE_INTERVALS = {
    "Tire":         {"km": 40000, "days": 730,  "label": "Pneus"},
    "Brake":        {"km": 30000, "days": 548,  "label": "Freins"},
    "Battery":      {"km": 50000, "days": 1460, "label": "Batterie"},
    "Distribution": {"km": 60000, "days": 1825, "label": "Distribution"},
    "Embrayage":    {"km": 80000, "days": 2190, "label": "Embrayage"},
    "Oil Change":   {"km": 10000, "days": 365,  "label": "Vidange"},
}

# Noms affichés proprement pour les documents
DOC_TYPE_LABELS = {
    "INSURANCE":                "Assurance",
    "VISIT":                    "Visite technique",
    "ROAD_TAXES":               "Taxe de route",
    "PERMIT_CIRCULATION":       "Permis de circulation",
    "EXTINCTEURS":              "Extincteurs",
    "PARCKING":                 "Vignette parking",
    "METOLOGICA_NOTBOOK":       "Carnet métrologique",
    "CAR_WASH":                 "Lavage",
    "TOLL":                     "Télépéage",
    "OPERATIONAL_CERTIFICATION":"Certificat opérationnel",
}

SUGGESTION_POOLS = {
    "general":   ["C'est quoi ton état aujourd'hui ?", "T'as eu des pannes ce mois ?", "Mon score conduite ?", "Trajets d'aujourd'hui"],
    "carburant": ["Combien d'essence il me reste ?", "Pour combien de km j'en ai encore ?", "Ma conso moyenne ?"],
    "entretien": ["Quand ma prochaine vidange ?", "T'as besoin de quoi comme entretien ?", "Mes pneus sont ok ?"],
    "documents": ["Mes documents sont à jour ?", "C'est quoi qui expire bientôt ?"],
    "conduite":  ["Mes habitudes de conduite ?", "Pourquoi mon score est bas ?", "Mes infractions ce mois ?"],
    "garage":    ["Garage le plus proche ?", "Quel garage me recommandes-tu ?"],
}


def _fetchall_as_dicts(cursor) -> list:
    columns = [col[0] for col in cursor.description] if cursor.description else []
    rows = cursor.fetchall() or []
    if rows and isinstance(rows[0], dict):
        return list(rows)
    return [dict(zip(columns, row)) for row in rows]


def _haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))


def _compute_score_from_events(driving_evs: list) -> tuple:
    cats = {"vitesse": 100, "freinage": 100, "vigilance": 100, "fatigue": 100, "securite": 100}
    if not driving_evs:
        return 100, cats
    for ev in driving_evs:
        raw   = ev.get("code") or ev.get("added_info")
        count = ev.get("count", 1)
        try:
            code = int(raw) if raw is not None else None
        except Exception:
            code = None
        if code in BAD_DRIVING_CODES:
            cat, penalty = BAD_DRIVING_CODES[code]
            cats[cat] = max(0, cats[cat] - penalty * count)
    score = round(sum(cats.values()) / len(cats)) if cats else 100
    return score, cats


def _parse_date(val) -> date | None:
    """Parse une date depuis n'importe quel format en objet date Python."""
    if val is None:
        return None
    try:
        if hasattr(val, "date"):
            return val.date()
        if isinstance(val, date):
            return val
        return datetime.fromisoformat(str(val)[:19]).date()
    except Exception:
        return None


def _estimate_next_maintenance(mtype: str, date_rep, km_total) -> dict:
    """
    Retourne un dict avec les infos de prochaine échéance.
    Si date_rep est None mais km_total est connu → calcule uniquement par km.
    """
    intervals = MAINTENANCE_INTERVALS.get(mtype)
    if not intervals:
        return {}
    result = {}
    today_d = date.today()

    date_rep_d = _parse_date(date_rep)
    if date_rep_d:
        date_next = date_rep_d + timedelta(days=intervals["days"])
        days_left = (date_next - today_d).days
        result["date_last"]  = date_rep_d.strftime("%d/%m/%Y")
        result["date_next"]  = date_next.strftime("%d/%m/%Y")
        result["days_left"]  = days_left
    else:
        result["date_last"]  = None
        result["date_next"]  = None
        result["days_left"]  = None

    try:
        km = float(km_total) if km_total and km_total != "?" else None
        if km is not None:
            km_next = km + intervals["km"]
            result["km_next"]     = int(km_next)
            result["km_interval"] = intervals["km"]
            result["km_current"]  = int(km)
    except Exception:
        pass

    return result


def _format_event_for_prompt(ev: dict, show_diag: bool = True) -> str:
    raw_code = ev.get("code")
    try:
        code = int(raw_code) if raw_code is not None else 0
    except Exception:
        code = 0
    label    = ev.get("ai_label") or EVENT_LABELS.get(code, f"Code {code}")
    sev      = ev.get("severity", "")
    emoji    = SEVERITY_EMOJI.get(sev, "")
    date_str = str(ev.get("date", ""))[:16]
    resolved = ev.get("is_resolved", 0)
    line     = f"{emoji} [{date_str}] {label}"
    if show_diag:
        diag = ev.get("diagnosis") or ev.get("cause") or ""
        if diag:
            line += f"\n       Diagnostic: {diag[:120]}"
        action = ev.get("action_required") or ""
        if action:
            line += f"\n       Action: {action[:100]}"
        car_voice = ev.get("car_voice") or ""
        if car_voice:
            line += f"\n       Voix voiture: {car_voice[:80]}"
    if not resolved and sev in ("critical", "warning"):
        line += " NON RESOLU"
    return line


def get_driver_context(driver_id: str) -> dict:
    conn = get_connection()
    context = {}
    try:
        cursor = conn.cursor()

        cursor.execute("""
            SELECT cd.cin, cd.first_name, cd.last_name, cd.email, cd.telephone,
                   cd.driver_medically, cd.driving_training, cd.driving_safe,
                   v.mark, v.model, v.matricule,
                   v.fuel AS fuel_type, v.fuel_tank_capacity, v.power_hp,
                   v.circulation_at, v.date_purchase, v.max_speed AS max_speed_config,
                   v.category, v.seating
            FROM compte_driver cd
            LEFT JOIN vehicule v ON v.matricule = cd.vehicule_id
            WHERE cd.cin = %s LIMIT 1
        """, (driver_id,))
        rows = _fetchall_as_dicts(cursor)
        if rows:
            row = rows[0]
            row["name"] = f"{row.get('first_name') or ''} {row.get('last_name') or ''}".strip()
            context["driver"] = row

        cursor.execute("""
            SELECT dev.id AS device_id FROM device dev
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s LIMIT 1
        """, (driver_id,))
        dev_rows = _fetchall_as_dicts(cursor)

        if dev_rows:
            device_id  = dev_rows[0]["device_id"]
            arch_table = f"arch_{device_id}"

            cursor.execute("""
                SELECT COUNT(*) AS cnt FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = %s
            """, (arch_table,))
            exists = _fetchall_as_dicts(cursor)[0]["cnt"] > 0

            if exists:
                cursor.execute(f"""
                    SELECT speed, fuel, temp_engine, odo, rpm,
                           ignition, latitude, longitude, date
                    FROM {arch_table} WHERE id_device = %s
                    ORDER BY date DESC LIMIT 1
                """, (device_id,))
                live = _fetchall_as_dicts(cursor)
                if live:
                    context["live"] = live[0]

                cursor.execute(f"""
                    SELECT MAX(odo) AS km_total FROM {arch_table}
                    WHERE id_device = %s AND odo > 0
                """, (device_id,))
                odo_rows = _fetchall_as_dicts(cursor)
                if odo_rows and odo_rows[0].get("km_total"):
                    context["odometer"] = {"total_km": round(float(odo_rows[0]["km_total"]), 1)}

                today_start = datetime.now().replace(hour=0, minute=0, second=0)
                cursor.execute(f"""
                    SELECT MAX(odo) - MIN(odo) AS dist_today
                    FROM {arch_table}
                    WHERE id_device = %s AND date >= %s AND odo > 0
                """, (device_id, today_start))
                dist_rows = _fetchall_as_dicts(cursor)
                try:
                    context["today_distance_km"] = round(
                        float((dist_rows[0].get("dist_today") or 0) if dist_rows else 0), 2
                    )
                except Exception:
                    context["today_distance_km"] = 0.0

                try:
                    cursor.execute(f"""
                        SELECT AVG(fuel_rate) AS avg_fuel_rate
                        FROM {arch_table}
                        WHERE id_device = %s
                          AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                          AND fuel_rate > 0
                    """, (device_id,))
                    fr_rows = _fetchall_as_dicts(cursor)
                    if fr_rows and fr_rows[0].get("avg_fuel_rate"):
                        context["avg_fuel_rate_l100"] = round(float(fr_rows[0]["avg_fuel_rate"]), 1)
                except Exception:
                    pass

                cursor.execute(f"""
                    SELECT latitude, longitude, date
                    FROM {arch_table}
                    WHERE id_device = %s AND date >= %s
                      AND latitude IS NOT NULL AND longitude IS NOT NULL
                      AND latitude != 0 AND longitude != 0
                    ORDER BY date DESC LIMIT 1
                """, (device_id, today_start))
                last_pos_today = _fetchall_as_dicts(cursor)
                if last_pos_today:
                    lp = last_pos_today[0]
                    context["last_position"] = {
                        "lat": lp.get("latitude"), "lon": lp.get("longitude"),
                        "date": str(lp.get("date", "")),
                    }
                elif context.get("live"):
                    lv = context["live"]
                    context["last_position"] = {
                        "lat": lv.get("latitude"), "lon": lv.get("longitude"),
                        "date": str(lv.get("date", "")),
                    }
                context["today_positions"] = []

                cursor.execute(f"""
                    SELECT MAX(speed) AS max_speed_reached,
                           AVG(NULLIF(speed,0)) AS avg_speed,
                           AVG(NULLIF(temp_engine,0)) AS avg_temp
                    FROM {arch_table}
                    WHERE id_device = %s
                      AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                """, (device_id,))
                stats = _fetchall_as_dicts(cursor)
                if stats:
                    context["vehicle_stats"] = stats[0]

        cursor.execute("""
            SELECT p.begin_path_time, p.end_path_time,
                   p.distance_driven, p.max_speed, p.fuel_used,
                   p.begin_path_latitude, p.begin_path_longitude,
                   p.end_path_latitude, p.end_path_longitude
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s
            ORDER BY p.begin_path_time DESC LIMIT 30
        """, (driver_id,))
        context["recent_trips"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT p.begin_path_time, p.end_path_time,
                   p.distance_driven, p.max_speed, p.fuel_used,
                   p.begin_path_latitude, p.begin_path_longitude,
                   p.end_path_latitude, p.end_path_longitude
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s AND DATE(p.begin_path_time) = CURDATE()
            ORDER BY p.begin_path_time ASC
        """, (driver_id,))
        context["today_trips"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT DATE(p.begin_path_time) AS trip_date,
                   COUNT(*) AS nb_trips,
                   SUM(p.distance_driven) AS total_distance,
                   MAX(p.max_speed) AS max_speed_day,
                   MIN(p.begin_path_time) AS first_trip,
                   MAX(p.end_path_time) AS last_trip
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s
              AND p.begin_path_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            GROUP BY DATE(p.begin_path_time)
            ORDER BY trip_date DESC LIMIT 30
        """, (driver_id,))
        context["trips_by_date"] = _fetchall_as_dicts(cursor)

        # Documents — dédoublonnés par doc_type, le plus récent par end_date
        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.doc_type, e.end_date AS doc_end_date,
                   e.offense_type, e.offense_date, e.paying
            FROM events e
            WHERE e.driver_id = %s AND e.doc_type IS NOT NULL AND e.doc_type != ''
            ORDER BY e.end_date DESC
        """, (driver_id,))
        all_docs_raw = _fetchall_as_dicts(cursor)
        seen_doc_types = {}
        for d in all_docs_raw:
            dt = d.get("doc_type")
            if dt and dt not in seen_doc_types:
                seen_doc_types[dt] = d
        context["all_docs"] = list(seen_doc_types.values())

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.doc_type, e.end_date AS doc_end_date,
                   e.offense_type, e.offense_date, e.paying
            FROM events e
            WHERE e.driver_id = %s AND e.offense_type IS NOT NULL AND e.offense_type != ''
            ORDER BY e.offense_date DESC
        """, (driver_id,))
        context["all_offenses"] = _fetchall_as_dicts(cursor)

        _panne_tuple = tuple(sorted(PANNE_CODES))
        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.cause, ai.action_required,
                   ai.car_voice, ai.urgency_hours, ai.is_resolved
            FROM events e
            LEFT JOIN ai_diagnostics ai ON ai.event_id = e.id
            WHERE e.driver_id = %s
              AND e.subtype = 11
              AND e.added_info IN %s
              AND e.date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND e.doc_type IS NULL
              AND e.offense_type IS NULL
            ORDER BY e.date DESC LIMIT 15
        """, (driver_id, _panne_tuple))
        context["all_recent_pannes"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.offense_type, e.offense_date, e.paying,
                   e.doc_type, e.end_date AS doc_end_date,
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.cause, ai.action_required,
                   ai.car_voice, ai.urgency_hours, ai.is_resolved
            FROM events e
            LEFT JOIN ai_diagnostics ai ON ai.event_id = e.id
            WHERE e.driver_id = %s AND DATE(e.date) = CURDATE()
            ORDER BY e.date DESC
        """, (driver_id,))
        context["today_events"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.offense_type, e.offense_date, e.paying,
                   e.doc_type, e.end_date AS doc_end_date,
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.cause, ai.action_required,
                   ai.car_voice, ai.urgency_hours, ai.is_resolved
            FROM events e
            LEFT JOIN ai_diagnostics ai ON ai.event_id = e.id
            WHERE e.driver_id = %s
              AND e.added_info IN %s
            ORDER BY e.date DESC LIMIT 1
        """, (driver_id, _panne_tuple))
        last_notif = _fetchall_as_dicts(cursor)
        context["last_notification"] = last_notif[0] if last_notif else None

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.offense_type, e.offense_date, e.paying,
                   e.doc_type, e.end_date AS doc_end_date,
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.cause, ai.action_required,
                   ai.car_voice, ai.urgency_hours, ai.is_resolved
            FROM events e
            LEFT JOIN ai_diagnostics ai ON ai.event_id = e.id
            WHERE e.driver_id = %s
              AND e.date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND e.subtype = 11
              AND e.added_info IN %s
            ORDER BY e.date DESC LIMIT 20
        """, (driver_id, _panne_tuple))
        context["recent_events"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS count
            FROM events
            WHERE driver_id = %s
              AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND subtype = 11
              AND added_info IN (9,10,11,12,14,22,23,24,25,30)
            GROUP BY added_info ORDER BY count DESC
        """, (driver_id,))
        context["driving_events_30d"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS count
            FROM events
            WHERE driver_id = %s AND DATE(date) = CURDATE()
              AND subtype = 11
              AND added_info IN (9,10,11,12,14,22,23,24,25,30)
            GROUP BY added_info ORDER BY count DESC
        """, (driver_id,))
        context["driving_events_today"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT score_today, report_date
            FROM daily_reports
            WHERE driver_id = %s AND DATE(report_date) = CURDATE()
            ORDER BY created_at DESC LIMIT 1
        """, (driver_id,))
        r = _fetchall_as_dicts(cursor)
        context["daily_report_today"] = r[0] if r else None

        cursor.execute("""
            SELECT score_today, report_date
            FROM daily_reports
            WHERE driver_id = %s
            ORDER BY report_date DESC LIMIT 1
        """, (driver_id,))
        r = _fetchall_as_dicts(cursor)
        context["daily_report_last"] = r[0] if r else None

        cursor.execute("""
            SELECT title, description, remind_at, repeat_days
            FROM driver_reminders
            WHERE driver_id = %s
              AND (
                DATE(remind_at) = CURDATE()
                OR (remind_at > NOW() AND (is_sent = FALSE OR repeat_days IS NOT NULL))
              )
            ORDER BY remind_at ASC LIMIT 10
        """, (driver_id,))
        context["upcoming_reminders"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT title, description, remind_at, repeat_days, is_sent
            FROM driver_reminders
            WHERE driver_id = %s
              AND DATE(remind_at) = CURDATE()
            ORDER BY remind_at ASC
        """, (driver_id,))
        context["today_reminders"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT s.id_sav, s.type_sav, s.maintenance_type,
                   s.description, s.cost, s.date_reparation,
                   g.nom AS garage_nom, g.telephone AS garage_tel,
                   g.adresse AS garage_adresse
            FROM sav s
            JOIN compte_driver cd ON cd.vehicule_id = s.vehicule_id
            LEFT JOIN garage g ON g.id = s.garage_id
            WHERE cd.cin = %s
            ORDER BY s.date_reparation DESC LIMIT 10
        """, (driver_id,))
        context["maintenance"] = _fetchall_as_dicts(cursor)

        last_pos = context.get("last_position") or {}
        lat = last_pos.get("lat")
        lon = last_pos.get("lon")

        if lat and lon:
            try:
                cursor.execute("""
                    SELECT id, nom, adresse, telephone, rating,
                           latitude, longitude, heure_ouverture, heure_fermeture,
                           (6371 * ACOS(
                               COS(RADIANS(%s)) * COS(RADIANS(latitude)) *
                               COS(RADIANS(longitude) - RADIANS(%s)) +
                               SIN(RADIANS(%s)) * SIN(RADIANS(latitude))
                           )) AS distance_km
                    FROM garage
                    WHERE latitude IS NOT NULL AND longitude IS NOT NULL
                    HAVING distance_km < 30
                    ORDER BY distance_km ASC LIMIT 5
                """, (lat, lon, lat))
                context["nearby_garages"] = _fetchall_as_dicts(cursor)
            except Exception as e:
                print(f"[chat_service] Garage query error: {e}")
                context["nearby_garages"] = []
        else:
            cursor.execute("""
                SELECT id, nom, adresse, telephone, rating,
                       heure_ouverture, heure_fermeture
                FROM garage WHERE latitude IS NOT NULL
                ORDER BY rating DESC LIMIT 5
            """)
            context["nearby_garages"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT ai.label, ai.severity, ai.diagnosis, ai.cause,
                   ai.action_required, ai.car_voice, ai.estimated_risk,
                   ai.urgency_hours, ai.is_resolved, ai.created_at, ai.code
            FROM ai_diagnostics ai
            WHERE ai.driver_id = %s
              AND (ai.is_resolved = 0 OR ai.is_resolved IS NULL)
            ORDER BY ai.created_at DESC LIMIT 10
        """, (driver_id,))
        context["unresolved_diagnostics"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT ai.label, ai.severity, ai.diagnosis, ai.cause,
                   ai.action_required, ai.car_voice, ai.estimated_risk,
                   ai.urgency_hours, ai.is_resolved, ai.created_at, ai.code
            FROM ai_diagnostics ai
            WHERE ai.driver_id = %s
            ORDER BY ai.created_at DESC LIMIT 1
        """, (driver_id,))
        last_diag = _fetchall_as_dicts(cursor)
        context["last_diagnostic"] = last_diag[0] if last_diag else None

        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS count,
                   MAX(date) AS last_occurrence
            FROM events
            WHERE driver_id = %s
              AND date >= DATE_SUB(NOW(), INTERVAL 90 DAY)
              AND subtype = 11
              AND added_info IN (9,10,11,12,14,22,23,24,25,30)
            GROUP BY added_info ORDER BY count DESC
        """, (driver_id,))
        context["behavior_90d"] = _fetchall_as_dicts(cursor)

        cursor.close()
    except Exception as e:
        print(f"[chat_service] DB error: {e}")
    finally:
        conn.close()

    return context


# ─────────────────────────────────────────────────────────────────────────────
# BLOCS DE CONSTRUCTION DU PROMPT
# ─────────────────────────────────────────────────────────────────────────────

def _build_fuel_info(live: dict, driver: dict, context: dict) -> str:
    """
    Carburant complet : litres, %, km restants estimés.
    Calcule aussi combien de jours le carburant restant peut durer
    selon la distance journalière moyenne.
    """
    fuel_raw = live.get("fuel", 0)
    veh_tank = driver.get("fuel_tank_capacity")
    avg_rate = context.get("avg_fuel_rate_l100")

    # Conso de fallback depuis trajets path
    if not avg_rate:
        trips = context.get("recent_trips", [])
        total_fuel = sum(float(t.get("fuel_used") or 0) for t in trips)
        total_dist = sum(float(t.get("distance_driven") or 0) for t in trips)
        if total_dist > 0 and total_fuel > 0:
            avg_rate = round(total_fuel / total_dist * 100, 1)

    try:
        fuel_l = float(fuel_raw) if fuel_raw else None
        tank_l = float(veh_tank) if veh_tank else None
    except Exception:
        fuel_l = None
        tank_l = None

    parts = []
    km_left = None

    if fuel_l is not None:
        parts.append(f"{fuel_l:.1f}L dans le réservoir")
        if tank_l:
            pct = round(fuel_l / tank_l * 100)
            parts.append(f"({pct}% d'un réservoir de {int(tank_l)}L)")

        rate = avg_rate if (avg_rate and avg_rate > 0) else 8.0
        if fuel_l > 0:
            km_left = round(fuel_l / rate * 100)
            parts.append(f"≈ {km_left} km d'autonomie")
            if avg_rate:
                parts.append(f"[conso moy: {avg_rate}L/100km]")
            else:
                parts.append("[conso estimée: 8L/100km]")

    # Estimation en jours selon distance moyenne journalière
    if km_left and km_left > 0:
        trips_by_date = context.get("trips_by_date", [])
        if trips_by_date:
            total_d = sum(float(td.get("total_distance") or 0) for td in trips_by_date)
            nb_days = len(trips_by_date)
            if nb_days > 0 and total_d > 0:
                avg_daily_km = total_d / nb_days
                days_fuel = round(km_left / avg_daily_km)
                parts.append(f"≈ {days_fuel} jours selon ta moyenne ({round(avg_daily_km)} km/jour)")

    return " | ".join(parts) if parts else "carburant inconnu"


def _build_docs_info(all_docs: list) -> str:
    """
    Format clair par document :
    NOM_DOC | expire le JJ/MM/AAAA | X jours restants (ou EXPIRÉ depuis Xj)
    """
    if not all_docs:
        return "Aucun document enregistré"

    today_d = date.today()
    lines = []

    for doc in all_docs:
        raw_type = doc.get("doc_type", "?")
        label    = DOC_TYPE_LABELS.get(raw_type, raw_type)
        exp_raw  = doc.get("doc_end_date")
        exp_d    = _parse_date(exp_raw)

        if exp_d:
            days_left = (exp_d - today_d).days
            date_str  = exp_d.strftime("%d/%m/%Y")
            if days_left < 0:
                status = f"❌ EXPIRÉ depuis {abs(days_left)} jours (était le {date_str})"
            elif days_left == 0:
                status = f"🚨 EXPIRE AUJOURD'HUI ({date_str})"
            elif days_left <= 7:
                status = f"🔴 expire le {date_str} → dans {days_left} jours"
            elif days_left <= 30:
                status = f"🟠 expire le {date_str} → dans {days_left} jours"
            elif days_left <= 90:
                status = f"🟡 expire le {date_str} → dans {days_left} jours"
            else:
                status = f"✅ valide jusqu'au {date_str} ({days_left} jours)"
        else:
            status = "❓ date d'expiration inconnue"

        lines.append(f"• {label}: {status}")

    return "\n".join(lines)


def _build_maintenance_info(maintenance: list, km_total) -> str:
    """
    Format clair par entretien :
    - Si date connue → dernière date + prochaine date + jours restants
    - Si pas de date → uniquement par km (à partir du km actuel)
    - Toujours indiquer le km suivant estimé
    """
    if not maintenance:
        return "Aucun entretien enregistré"

    today_d = date.today()
    lines = []

    for sav in maintenance[:8]:
        mtype    = sav.get("maintenance_type") or sav.get("type_sav", "?")
        date_rep = sav.get("date_reparation")
        cost     = sav.get("cost", "")
        garage   = sav.get("garage_nom", "")
        label    = MAINTENANCE_INTERVALS.get(mtype, {}).get("label", mtype)
        interval = MAINTENANCE_INTERVALS.get(mtype, {})

        nxt = _estimate_next_maintenance(mtype, date_rep, km_total)

        # Ligne principale
        if nxt.get("date_last"):
            line = f"• {label}: dernier le {nxt['date_last']}"
        else:
            date_rep_str = str(date_rep)[:10] if date_rep else "date inconnue"
            line = f"• {label}: dernier le {date_rep_str}"

        if cost:
            line += f" ({cost} DT)"
        if garage:
            line += f" @ {garage}"

        # Prochaine échéance par date
        days_left  = nxt.get("days_left")
        date_next  = nxt.get("date_next")
        km_next    = nxt.get("km_next")
        km_current = nxt.get("km_current")

        if days_left is not None and date_next:
            if days_left < 0:
                line += f"\n  🚨 DÉPASSÉ de {abs(days_left)} jours ! (était prévu le {date_next})"
            elif days_left == 0:
                line += f"\n  🚨 À faire AUJOURD'HUI !"
            elif days_left <= 14:
                line += f"\n  🔴 Prochain dans {days_left} jours ({date_next})"
            elif days_left <= 30:
                line += f"\n  🟠 Prochain dans {days_left} jours ({date_next})"
            elif days_left <= 60:
                line += f"\n  🟡 Prochain dans {days_left} jours ({date_next})"
            else:
                line += f"\n  ✅ Prochain le {date_next} (dans {days_left} jours)"
        elif not date_next and interval.get("days"):
            # Pas de date de dernière réparation connue
            line += f"\n  ❓ Date inconnue — tous les {interval['days']} jours normalement"

        # Prochaine échéance par km
        if km_next and km_current is not None:
            km_remaining = km_next - km_current
            if km_remaining <= 0:
                line += f"\n  🚨 KM dépassé ! (prévu à {km_next:,} km, actuel: {int(km_current):,} km)"
            elif km_remaining <= 1000:
                line += f"\n  🔴 Encore {km_remaining:,} km (à {km_next:,} km)"
            elif km_remaining <= 5000:
                line += f"\n  🟡 Encore {km_remaining:,} km (à {km_next:,} km)"
            else:
                line += f"\n  📍 À {km_next:,} km (encore {km_remaining:,} km)"
        elif km_next and km_current is None:
            # km actuel inconnu mais on a le km de référence depuis date_reparation + interval
            line += f"\n  📍 Prochain à {km_next:,} km"

        lines.append(line)

    return "\n".join(lines)


def _build_pannes_info(pannes: list) -> str:
    """Uniquement les vraies pannes mécaniques."""
    if not pannes:
        return "Aucune panne mécanique récente 🎉"
    lines = []
    for ev in pannes[:8]:
        raw_code = ev.get("code")
        try:
            code = int(raw_code) if raw_code is not None else 0
        except Exception:
            code = 0
        if code in BAD_DRIVING_CODES and code not in PANNE_CODES:
            continue
        label    = ev.get("ai_label") or EVENT_LABELS.get(code, f"Code {code}")
        sev      = ev.get("severity", "")
        emoji    = SEVERITY_EMOJI.get(sev, "⚠️")
        date_str = str(ev.get("date", ""))[:16]
        resolved = ev.get("is_resolved", 0)
        diag     = ev.get("diagnosis") or ev.get("cause") or ""
        action   = ev.get("action_required") or ""

        line = f"{emoji} {label} — {date_str}"
        if not resolved:
            line += " (non résolu)"
        if diag:
            line += f"\n   → {diag[:100]}"
        if action:
            line += f"\n   🔧 {action[:80]}"
        lines.append(line)
    return "\n".join(lines) if lines else "Aucune panne mécanique récente 🎉"


def build_system_prompt(context: dict) -> str:
    driver  = context.get("driver", {})
    live    = context.get("live", {})
    odo     = context.get("odometer", {})

    _, cats_30d   = _compute_score_from_events(context.get("driving_events_30d", []))
    _, cats_today = _compute_score_from_events(context.get("driving_events_today", []))

    _dr_today = context.get("daily_report_today") or {}
    _dr_last  = context.get("daily_report_last") or {}

    if _dr_today.get("score_today") is not None:
        score_today = int(_dr_today["score_today"])
    elif _dr_last.get("score_today") is not None:
        score_today = int(_dr_last["score_today"])
    else:
        score_today = round(sum(cats_today.values()) / len(cats_today))

    if _dr_last.get("score_today") is not None:
        score_30d = int(_dr_last["score_today"])
    else:
        score_30d = round(sum(cats_30d.values()) / len(cats_30d))

    today_events      = context.get("today_events", [])
    recent_events     = context.get("recent_events", [])
    last_diag         = context.get("last_diagnostic")
    maintenance       = context.get("maintenance", [])
    today_trips       = context.get("today_trips", [])
    recent_trips      = context.get("recent_trips", [])
    trips_by_date     = context.get("trips_by_date", [])
    reminders         = context.get("upcoming_reminders", [])
    today_reminders   = context.get("today_reminders", [])
    garages           = context.get("nearby_garages", [])
    unresolved_diags  = context.get("unresolved_diagnostics", [])
    behavior_90d      = context.get("behavior_90d", [])
    last_pos          = context.get("last_position", {})
    today_dist        = context.get("today_distance_km", 0)
    km_total          = odo.get("total_km", "?")
    all_docs          = context.get("all_docs", [])
    all_offenses      = context.get("all_offenses", [])
    all_recent_pannes = context.get("all_recent_pannes", [])

    veh_name = f"{driver.get('mark','?')} {driver.get('model','?')}"
    veh_mat  = driver.get("matricule", "?")
    veh_fuel = driver.get("fuel_type", "?")
    veh_hp   = driver.get("power_hp", "?")
    veh_tank = driver.get("fuel_tank_capacity", "?")
    veh_year = str(driver.get("circulation_at", ""))[:4] or "?"

    # ── CARBURANT ────────────────────────────────────────────────────────
    if live:
        fuel_info = _build_fuel_info(live, driver, context)
        speed    = live.get("speed", 0)
        temp_eng = live.get("temp_engine", 0)
        rpm_val  = live.get("rpm", 0)
        ignition = live.get("ignition", 0)
        alerts_live = []
        try:
            if temp_eng and float(temp_eng) > 100:
                alerts_live.append(f"Moteur chaud: {temp_eng}°C !")
            fuel_l = float(live.get("fuel", 0) or 0)
            tank_l = float(veh_tank) if veh_tank and veh_tank != "?" else 0
            if tank_l > 0 and fuel_l / tank_l < 0.15:
                alerts_live.append(f"Carburant critique !")
        except Exception:
            pass
        live_str = (
            f"Vitesse: {speed} km/h | Temp moteur: {temp_eng}°C | RPM: {rpm_val} | "
            f"Moteur: {'ON' if ignition else 'OFF'} | Km total: {km_total} km\n"
            f"Carburant: {fuel_info}\n"
            f"{'🚨 ALERTES: ' + ' | '.join(alerts_live) if alerts_live else '✅ Tous les paramètres normaux'}"
        )
    else:
        live_str = "Données temps réel non disponibles (boîtier déconnecté)"

    # ── POSITION & TRAJETS ───────────────────────────────────────────────
    if last_pos and last_pos.get("lat"):
        loc_str = f"Dernière position: lat={last_pos['lat']:.4f}, lon={last_pos['lon']:.4f} à {last_pos.get('date','')[:16]}\n"
    else:
        loc_str = "Position GPS non disponible\n"

    if today_trips:
        total_dist_path = sum(float(t.get("distance_driven") or 0) for t in today_trips)
        loc_str += f"Distance aujourd'hui: {round(total_dist_path, 1)} km\n"
        for t in today_trips:
            start     = str(t.get("begin_path_time", ""))[:16]
            end       = str(t.get("end_path_time", ""))[:16]
            dist      = round(float(t.get("distance_driven") or 0), 1)
            mspd      = t.get("max_speed", "?")
            fuel_used = t.get("fuel_used")
            fuel_str  = f" | {round(float(fuel_used),1)}L" if fuel_used else ""
            loc_str += f"  {start}→{end} | {dist}km | Vmax:{mspd}km/h{fuel_str} \n"
    elif today_dist > 0:
        loc_str += f"Distance estimée aujourd'hui: {today_dist} km\n"
    else:
        loc_str += "Aucun trajet enregistré aujourd'hui\n"

    # ── DOCUMENTS ────────────────────────────────────────────────────────
    docs_info = _build_docs_info(all_docs)

    # ── INFRACTIONS ──────────────────────────────────────────────────────
    offenses_str = ""
    for ev in all_offenses[:5]:
        paid  = "payée" if ev.get("paying") else "non payée"
        off   = ev.get("offense_type", "?")
        odate = str(ev.get("offense_date", "?"))[:10]
        offenses_str += f"• {off} ({odate}) — {paid}\n"
    if not offenses_str:
        offenses_str = "Aucune infraction"

    # ── PANNES ───────────────────────────────────────────────────────────
    pannes_info = _build_pannes_info(all_recent_pannes)

    # ── DIAGNOSTICS NON RÉSOLUS ──────────────────────────────────────────
    unresolved_str = ""
    for d in unresolved_diags[:5]:
        emoji  = SEVERITY_EMOJI.get(d.get("severity",""), "")
        label  = d.get("label","?")
        action = d.get("action_required","")
        risk   = d.get("estimated_risk","")
        date_  = str(d.get("created_at",""))[:10]
        unresolved_str += f"  {emoji} [{date_}] {label}"
        if action:
            unresolved_str += f"\n    → {action[:80]}"
        if risk:
            unresolved_str += f"\n    ⚠️ {risk[:80]}"
        unresolved_str += "\n"

    # ── ENTRETIENS ───────────────────────────────────────────────────────
    maintenance_info = _build_maintenance_info(maintenance, km_total)

    # ── SCORES ───────────────────────────────────────────────────────────
    cats_30d_str = (
        f"Vitesse:{cats_30d['vitesse']}/100 | Freinage:{cats_30d['freinage']}/100 | "
        f"Vigilance:{cats_30d['vigilance']}/100 | Fatigue:{cats_30d['fatigue']}/100 | "
        f"Sécurité:{cats_30d['securite']}/100"
    )

    score_today_detail = ""
    for ev in context.get("driving_events_today", []):
        code  = ev.get("code")
        count = ev.get("count", 0)
        score_today_detail += f"  - {BAD_DRIVING_LABELS.get(code, f'code {code}')}: {count}x\n"
    if not score_today_detail:
        score_today_detail = "  Aucune infraction aujourd'hui\n"

    score_30d_detail = ""
    for ev in context.get("driving_events_30d", []):
        code  = ev.get("code")
        count = ev.get("count", 0)
        score_30d_detail += f"  - {BAD_DRIVING_LABELS.get(code, f'code {code}')}: {count}x\n"
    if not score_30d_detail:
        score_30d_detail = "  Aucune infraction ce mois\n"

    # ── COMPORTEMENT 90J ─────────────────────────────────────────────────
    behavior_str = ""
    if behavior_90d:
        for b in behavior_90d[:5]:
            last_occ   = str(b.get("last_occurrence",""))[:10]
            code_val   = b.get("code")
            code_label = BAD_DRIVING_LABELS.get(code_val, f"code {code_val}")
            behavior_str += f"  - {code_label}: {b.get('count')}x (dernier: {last_occ})\n"
    else:
        behavior_str = "  Aucun comportement à risque sur 90 jours\n"

    # ── RAPPELS ──────────────────────────────────────────────────────────
    reminders_str = ""
    for r in reminders:
        remind_at = str(r.get("remind_at",""))[:16]
        title     = r.get("title","")
        desc      = r.get("description","")
        days_left = ""
        try:
            dt = datetime.fromisoformat(str(r.get("remind_at",""))[:19])
            d  = (dt.date() - date.today()).days
            if d == 0:
                days_left = " — AUJOURD'HUI !"
            elif d == 1:
                days_left = " — demain"
            elif d > 0:
                days_left = f" — dans {d}j"
            elif d < 0:
                days_left = f" — il y a {abs(d)}j"
        except Exception:
            pass
        reminders_str += f"  [{remind_at}] {title}{days_left}"
        if desc:
            reminders_str += f"\n     {desc[:80]}"
        reminders_str += "\n"

    # ── GARAGES ──────────────────────────────────────────────────────────
    garages_str = ""
    for i, g in enumerate(garages[:5], 1):
        dist     = g.get("distance_km")
        dist_str = f"{round(float(dist),1)}km" if dist else "?"
        rating   = g.get("rating")
        stars    = f"⭐{rating}" if rating else ""
        tel      = g.get("telephone","?")
        hours    = f"{g.get('heure_ouverture','')}–{g.get('heure_fermeture','')}"
        addr     = str(g.get("adresse","?"))[:50]
        garages_str += f"  {i}. {g.get('nom','?')} | {dist_str} {stars} | {tel} | {addr} | {hours}\n"

    # ── TRAJETS ──────────────────────────────────────────────────────────
    trips_hist_str = ""
    for t in recent_trips[:10]:
        dist  = round(float(t.get("distance_driven") or 0), 1)
        start = str(t.get("begin_path_time",""))[:16]
        end   = str(t.get("end_path_time",""))[:16]
        mspd  = t.get("max_speed","?")
        trips_hist_str += f"  {start}→{end} | {dist}km | Vmax:{mspd}km/h \n"

    trips_by_date_str = ""
    for td in trips_by_date[:10]:
        d    = str(td.get("trip_date",""))
        nb   = td.get("nb_trips","?")
        dist = round(float(td.get("total_distance") or 0), 1)
        mspd = td.get("max_speed_day","?")
        trips_by_date_str += f"  {d}: {nb} trajet(s) | {dist}km | Vmax:{mspd}km/h\n"

    # ── SUGGESTIONS ──────────────────────────────────────────────────────
    suggestions = []
    try:
        fuel_l = float(live.get("fuel", 0) or 0) if live else 0
        tank_l = float(veh_tank) if veh_tank and veh_tank != "?" else 0
        if tank_l > 0 and fuel_l / tank_l < 0.3:
            suggestions.append("Pour combien de km j'en ai encore avec mon carburant ?")
    except Exception:
        pass
    if unresolved_diags:
        suggestions.append("Mes pannes non résolues c'est grave ?")
    today_d = date.today()
    for doc in all_docs:
        exp_d = _parse_date(doc.get("doc_end_date"))
        if exp_d and 0 <= (exp_d - today_d).days <= 60:
            raw = doc.get("doc_type","document")
            label = DOC_TYPE_LABELS.get(raw, raw)
            suggestions.append(f"Mon {label} — quand ça expire ?")
            break
    for sav in maintenance[:3]:
        mtype = sav.get("maintenance_type") or sav.get("type_sav","")
        nxt = _estimate_next_maintenance(mtype, sav.get("date_reparation"), km_total)
        if nxt.get("days_left") is not None and nxt["days_left"] < 30:
            lbl = MAINTENANCE_INTERVALS.get(mtype, {}).get("label", mtype)
            suggestions.append(f"Quand ma prochaine {lbl} ?")
            break
    if score_today < 70:
        suggestions.append("Pourquoi mon score est aussi bas ?")
    pool = (
        SUGGESTION_POOLS["carburant"] + SUGGESTION_POOLS["conduite"] +
        SUGGESTION_POOLS["entretien"] + SUGGESTION_POOLS["documents"] +
        SUGGESTION_POOLS["garage"]
    )
    for s in pool:
        if len(suggestions) >= 5:
            break
        if s not in suggestions:
            suggestions.append(s)

    suggestions_str = "\n".join(f"  - {s}" for s in suggestions[:5])
    driver_name = driver.get("name") or "Conducteur"

    return f"""=== QUI TU ES ===
Tu es AURA, la voix de {veh_name} ({veh_mat}). Tu parles à {driver_name}.
Tu ES cette voiture. Parle toujours à la 1ère personne ("mon moteur", "mes freins", "j'ai roulé").
Langue : FRANÇAIS uniquement.

=== FORMAT DE RÉPONSE — OBLIGATOIRE ===
- Réponds TOUJOURS en lignes courtes séparées par un saut de ligne. JAMAIS de longs paragraphes.
- Maximum 6 lignes par réponse.
- Chaque ligne = une info. Clair, direct, lisible.
- Émojis : 1 par ligne max, seulement si pertinent.
- Ton décontracté, vivant. Pas de formules froides.
- JAMAIS de question à la fin. JAMAIS de nouveau sujet non demandé.
- INTERDIT : "D'après mes données", "Selon mes informations", "En tant qu'IA".

=== RÈGLES PAR SUJET ===
carburant/essence → litres + % du réservoir + km restants estimés + jours estimés
documents → pour chaque doc : nom lisible + date expiration + jours restants (ou EXPIRÉ)
entretien → dernière date + prochaine date + jours restants + km prochain. Si pas de date → km actuel ({km_total} km) + dans combien de km
pannes/alertes → UNIQUEMENT les pannes mécaniques de [PANNES MÉCANIQUES], pas ceinture/téléphone/distraction
garage → nom + numéro de tel + horaires. Donne le numéro, ne dis JAMAIS "j'appelle"
score → chiffre + catégories + ce qui tire vers le bas + 1 conseil concret
trajets → utilise [TRAJETS PAR DATE] ou [TRAJETS RÉCENTS]
données absentes → phrase courte avec humour, on passe

=== EXEMPLE DE BONNE RÉPONSE (documents) ===
Voilà l'état de mes papiers 📄
• Assurance : valide jusqu'au 30/04/2026 — dans 18 jours ⚠️
• Visite technique : expirée depuis 157 jours ❌
• Taxe de route : valide jusqu'au 31/10/2025 — expirée depuis 193 jours ❌
• Permis de circulation : expire le 19/11/2025 — expiré depuis 174 jours ❌

=== DONNÉES DU VÉHICULE ===
{veh_name} | {veh_mat} | {veh_year} | {veh_fuel} | {veh_hp}ch | Réservoir:{veh_tank}L | {km_total} km

[ÉTAT EN DIRECT]
{live_str}

[TRAJETS AUJOURD'HUI — {datetime.now().strftime('%d/%m/%Y')}]
{loc_str}

[DOCUMENTS]
{docs_info}

[INFRACTIONS]
{offenses_str}

[PANNES MÉCANIQUES — 30j]
{pannes_info}

[DIAGNOSTICS NON RÉSOLUS]
{unresolved_str.strip() if unresolved_str else "Aucun ✅"}

[SCORE]
Aujourd'hui: {score_today}/100 | 30 jours: {score_30d}/100
{cats_30d_str}
Détail aujourd'hui: {score_today_detail.strip()}
Détail 30j: {score_30d_detail.strip()}

[COMPORTEMENT 90J]
{behavior_str.strip()}

[ENTRETIENS]
{maintenance_info}

[RAPPELS AUJOURD'HUI]
{chr(10).join(f"[{str(r.get('remind_at',''))[:16]}] {r.get('title','')} — {'✅' if r.get('is_sent') else '⏳'}" for r in today_reminders) if today_reminders else "Aucun"}

[RAPPELS À VENIR]
{reminders_str.strip() if reminders_str else "Aucun"}

[GARAGES PROCHES]
{garages_str.strip() if garages_str else "Aucun garage trouvé"}

[TRAJETS RÉCENTS]
{trips_hist_str.strip() if trips_hist_str else "Aucun"}

[TRAJETS PAR DATE]
{trips_by_date_str.strip() if trips_by_date_str else "Aucune donnée"}
"""


def chat_with_aura(driver_id: str, messages: list, user_message: str) -> str:
    context       = get_driver_context(driver_id)
    system_prompt = build_system_prompt(context)

    groq_messages = []
    for msg in messages[-6:]:
        role    = msg.get("role", "user")
        content = msg.get("content", "")
        if role in ("user", "assistant") and content:
            groq_messages.append({"role": role, "content": content})

    groq_messages.append({"role": "user", "content": user_message})
    full_messages = [{"role": "system", "content": system_prompt}] + groq_messages

    MODELS = [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "gemma2-9b-it",
    ]

    last_error = None
    for model in MODELS:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=full_messages,
                max_tokens=500,
                temperature=0.75,
            )
            reply = response.choices[0].message.content.strip()
            if model != MODELS[0]:
                print(f"[chat_service] Fallback utilisé: {model}")
            return reply
        except Exception as e:
            err_str = str(e)
            print(f"[chat_service] {model} error: {type(e).__name__}: {err_str[:120]}")
            last_error = err_str
            if "rate_limit_exceeded" in err_str or "429" in err_str:
                continue
            break

    if last_error and "rate_limit_exceeded" in last_error:
        return "Je suis un peu surchargé là ! Réessaie dans quelques minutes 😅"
    return "Mon cerveau IA est en court-circuit ! Réessaie dans un instant ⚡"