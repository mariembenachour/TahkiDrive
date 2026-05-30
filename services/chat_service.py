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
    try:
        dlat = radians(float(lat2) - float(lat1))
        dlon = radians(float(lon2) - float(lon1))
        a = sin(dlat/2)**2 + cos(radians(float(lat1)))*cos(radians(float(lat2)))*sin(dlon/2)**2
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    except Exception:
        return 0.0


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


def _get_odo_at_date(cursor, arch_table: str, device_id, target_date) -> float | None:
    """
    Retourne l'odomètre le plus proche de target_date (avant ou juste après).
    Cherche d'abord avant, puis après si rien trouvé.
    """
    try:
        # Cherche le dernier odo AVANT ou AU MOMENT de la réparation
        cursor.execute(f"""
            SELECT odo FROM `{arch_table}`
            WHERE id_device = %s
              AND date <= %s
              AND odo IS NOT NULL AND odo > 0
            ORDER BY date DESC LIMIT 1
        """, (device_id, target_date))
        row = cursor.fetchone()
        if row:
            return float(row["odo"] if isinstance(row, dict) else row[0])

        # Si rien avant, prend le premier odo disponible (le véhicule était peut-être éteint)
        cursor.execute(f"""
            SELECT odo FROM `{arch_table}`
            WHERE id_device = %s
              AND odo IS NOT NULL AND odo > 0
            ORDER BY date ASC LIMIT 1
        """, (device_id,))
        row = cursor.fetchone()
        if row:
            return float(row["odo"] if isinstance(row, dict) else row[0])
    except Exception as e:
        print(f"[chat_service] _get_odo_at_date error: {e}")
    return None


def _get_odo_current(cursor, arch_table: str, device_id) -> float | None:
    """Retourne l'odomètre actuel (dernier enregistrement)."""
    try:
        cursor.execute(f"""
            SELECT odo FROM `{arch_table}`
            WHERE id_device = %s
              AND odo IS NOT NULL AND odo > 0
            ORDER BY date DESC LIMIT 1
        """, (device_id,))
        row = cursor.fetchone()
        if row:
            return float(row["odo"] if isinstance(row, dict) else row[0])
    except Exception as e:
        print(f"[chat_service] _get_odo_current error: {e}")
    return None


def _estimate_next_maintenance(mtype: str, date_rep, arch_table: str | None,
                                device_id, cursor) -> dict:
    """
    Calcule le prochain entretien.

    Priorité KM (fiable) :
      km_depuis_reparation = odo_actuel - odo_au_moment_reparation
      km_restants          = interval_km - km_depuis_reparation

    Date (approximation) :
      Uniquement pour afficher "dans environ X jours" côté prompt.
      Si on a les km, on estime la date depuis la vitesse moyenne journalière.
      Sinon, on utilise date_reparation + interval_days comme fallback.
    """
    intervals = MAINTENANCE_INTERVALS.get(mtype)
    if not intervals:
        return {}

    result    = {}
    today_d   = date.today()
    date_rep_d = _parse_date(date_rep)

    if date_rep_d:
        result["date_last"] = date_rep_d.strftime("%d/%m/%Y")
    else:
        result["date_last"] = None

    interval_km   = intervals["km"]
    interval_days = intervals["days"]

    # ── KM : calcul exact depuis arch_ ────────────────────────────────────────
    km_since_repair  = None
    odo_at_repair    = None
    odo_now          = None

    if arch_table and device_id:
        if date_rep_d:
            odo_at_repair = _get_odo_at_date(cursor, arch_table, device_id, date_rep_d)
        odo_now = _get_odo_current(cursor, arch_table, device_id)

        if odo_at_repair is not None and odo_now is not None and odo_now >= odo_at_repair:
            km_since_repair = round(odo_now - odo_at_repair, 1)

    if km_since_repair is not None:
        km_remaining = interval_km - km_since_repair
        km_next      = int(odo_now + max(0, km_remaining)) if odo_now else None

        result["km_since_repair"] = int(km_since_repair)
        result["km_interval"]     = interval_km
        result["km_current"]      = int(odo_now) if odo_now else None
        result["km_next"]         = km_next
        result["km_remaining"]    = int(km_remaining)
        result["km_source"]       = "exact"  # données réelles arch_

        # Estimation date depuis km restants + vitesse moyenne journalière
        if km_remaining > 0 and odo_now and date_rep_d:
            days_since_repair = (today_d - date_rep_d).days
            if days_since_repair > 7:
                avg_km_per_day = km_since_repair / days_since_repair
                if avg_km_per_day > 0:
                    days_until_next = int(km_remaining / avg_km_per_day)
                    date_next       = today_d + timedelta(days=days_until_next)
                    result["date_next"]  = date_next.strftime("%d/%m/%Y")
                    result["days_left"]  = days_until_next
                    result["date_source"] = "estimee_depuis_km"  # pas exacte !
                else:
                    # Pas de déplacement récent → fallback date
                    _fill_date_fallback(result, date_rep_d, interval_days, today_d)
            else:
                # Trop peu de jours pour estimer la vitesse → fallback date
                _fill_date_fallback(result, date_rep_d, interval_days, today_d)
        elif km_remaining <= 0:
            # Déjà dépassé en km
            result["date_next"]  = today_d.strftime("%d/%m/%Y")
            result["days_left"]  = 0
            result["date_source"] = "depasse"
        else:
            _fill_date_fallback(result, date_rep_d, interval_days, today_d)
    else:
        # Pas d'accès arch_ → fallback date uniquement
        result["km_source"] = "indisponible"
        if odo_now:
            result["km_current"] = int(odo_now)
        _fill_date_fallback(result, date_rep_d, interval_days, today_d)

    return result


def _fill_date_fallback(result: dict, date_rep_d, interval_days: int, today_d):
    """Remplit date_next / days_left depuis date_reparation + interval_days."""
    if date_rep_d:
        date_next = date_rep_d + timedelta(days=interval_days)
        result["date_next"]   = date_next.strftime("%d/%m/%Y")
        result["days_left"]   = (date_next - today_d).days
        result["date_source"] = "date_fixe"
    else:
        result["date_next"]   = None
        result["days_left"]   = None
        result["date_source"] = "inconnue"


def get_driver_context(driver_id: str) -> dict:
    conn = get_connection()
    context = {}
    try:
        cursor = conn.cursor()

        # ── DRIVER + VEHICULE ─────────────────────────────────────────────
        cursor.execute("""
            SELECT cd.cin, cd.first_name, cd.last_name, cd.email, cd.telephone,
                   cd.driver_medically, cd.driving_training, cd.driving_safe,
                   v.mark, v.model, v.matricule,
                   v.fuel AS fuel_type,
                   v.fuel_tank_capacity, v.power_hp,
                   v.circulation_at,
                   v.max_speed AS max_speed_config,
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

        # ── DEVICE ───────────────────────────────────────────────────────
        cursor.execute("""
            SELECT dev.id AS device_id FROM device dev
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s LIMIT 1
        """, (driver_id,))
        dev_rows = _fetchall_as_dicts(cursor)

        arch_table = None
        device_id  = None

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
                    FROM `{arch_table}` WHERE id_device = %s
                    ORDER BY date DESC LIMIT 1
                """, (device_id,))
                live = _fetchall_as_dicts(cursor)
                if live:
                    context["live"] = live[0]

                cursor.execute(f"""
                    SELECT MAX(odo) AS km_total FROM `{arch_table}`
                    WHERE id_device = %s AND odo > 0
                """, (device_id,))
                odo_rows = _fetchall_as_dicts(cursor)
                if odo_rows and odo_rows[0].get("km_total"):
                    context["odometer"] = {"total_km": round(float(odo_rows[0]["km_total"]), 1)}

                today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                cursor.execute(f"""
                    SELECT MAX(odo) - MIN(odo) AS dist_today
                    FROM `{arch_table}`
                    WHERE id_device = %s AND date >= %s AND odo > 0
                """, (device_id, today_start))
                dist_rows = _fetchall_as_dicts(cursor)
                try:
                    context["today_distance_km"] = round(
                        float((dist_rows[0].get("dist_today") or 0) if dist_rows else 0), 2
                    )
                except Exception:
                    context["today_distance_km"] = 0.0

                cursor.execute(f"""
                    SELECT latitude, longitude, date
                    FROM `{arch_table}`
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

                cursor.execute(f"""
                    SELECT MAX(speed) AS max_speed_reached,
                           AVG(NULLIF(speed, 0)) AS avg_speed,
                           AVG(NULLIF(temp_engine, 0)) AS avg_temp
                    FROM `{arch_table}`
                    WHERE id_device = %s
                      AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                """, (device_id,))
                stats = _fetchall_as_dicts(cursor)
                if stats:
                    context["vehicle_stats"] = stats[0]
            else:
                arch_table = None  # table n'existe pas

        # Stocke arch_table et device_id dans le contexte pour _build_maintenance_info
        context["_arch_table"] = arch_table
        context["_device_id"]  = device_id

        # ── TRAJETS (path) ────────────────────────────────────────────────
        DIST_SQL = """
            ROUND(
                6371 * 2 * ASIN(SQRT(
                    POW(SIN((RADIANS(p.end_path_latitude) - RADIANS(p.begin_path_latitude)) / 2), 2) +
                    COS(RADIANS(p.begin_path_latitude)) * COS(RADIANS(p.end_path_latitude)) *
                    POW(SIN((RADIANS(p.end_path_longitude) - RADIANS(p.begin_path_longitude)) / 2), 2)
                )), 2
            )
        """

        cursor.execute(f"""
            SELECT p.begin_path_time, p.end_path_time,
                   p.begin_path_latitude, p.begin_path_longitude,
                   p.end_path_latitude, p.end_path_longitude,
                   {DIST_SQL} AS distance_driven
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s
              AND p.begin_path_latitude IS NOT NULL
              AND p.end_path_latitude IS NOT NULL
            ORDER BY p.begin_path_time DESC LIMIT 30
        """, (driver_id,))
        context["recent_trips"] = _fetchall_as_dicts(cursor)

        cursor.execute(f"""
            SELECT p.begin_path_time, p.end_path_time,
                   p.begin_path_latitude, p.begin_path_longitude,
                   p.end_path_latitude, p.end_path_longitude,
                   {DIST_SQL} AS distance_driven
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s
              AND DATE(p.begin_path_time) = CURDATE()
              AND p.begin_path_latitude IS NOT NULL
              AND p.end_path_latitude IS NOT NULL
            ORDER BY p.begin_path_time ASC
        """, (driver_id,))
        context["today_trips"] = _fetchall_as_dicts(cursor)

        cursor.execute(f"""
            SELECT DATE(p.begin_path_time) AS trip_date,
                   COUNT(*) AS nb_trips,
                   ROUND(SUM(
                       6371 * 2 * ASIN(SQRT(
                           POW(SIN((RADIANS(p.end_path_latitude) - RADIANS(p.begin_path_latitude)) / 2), 2) +
                           COS(RADIANS(p.begin_path_latitude)) * COS(RADIANS(p.end_path_latitude)) *
                           POW(SIN((RADIANS(p.end_path_longitude) - RADIANS(p.begin_path_longitude)) / 2), 2)
                       ))
                   ), 2) AS total_distance,
                   MIN(p.begin_path_time) AS first_trip,
                   MAX(p.end_path_time) AS last_trip
            FROM path p
            JOIN device dev ON dev.id = p.device_id
            JOIN compte_driver cd ON cd.vehicule_id = dev.vehicule_id
            WHERE cd.cin = %s
              AND p.begin_path_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND p.begin_path_latitude IS NOT NULL
              AND p.end_path_latitude IS NOT NULL
            GROUP BY DATE(p.begin_path_time)
            ORDER BY trip_date DESC LIMIT 30
        """, (driver_id,))
        context["trips_by_date"] = _fetchall_as_dicts(cursor)

        # ── DOCUMENTS ────────────────────────────────────────────────────
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

        # ── INFRACTIONS ──────────────────────────────────────────────────
        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.doc_type, e.end_date AS doc_end_date,
                   e.offense_type, e.offense_date, e.paying
            FROM events e
            WHERE e.driver_id = %s AND e.offense_type IS NOT NULL AND e.offense_type != ''
            ORDER BY e.offense_date DESC
        """, (driver_id,))
        context["all_offenses"] = _fetchall_as_dicts(cursor)

        # ── PANNES MÉCANIQUES ─────────────────────────────────────────────
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

        # ── ÉVÉNEMENTS AUJOURD'HUI ────────────────────────────────────────
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
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.action_required, ai.car_voice, ai.is_resolved
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

        # ── CONDUITE ─────────────────────────────────────────────────────
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

        # ── SCORES ───────────────────────────────────────────────────────
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

       

        # ── ENTRETIENS (sav) ──────────────────────────────────────────────
        cursor.execute("""
            SELECT s.id_sav, s.maintenance_type,
                s.description, s.cost, s.date_reparation
            FROM sav s
            JOIN compte_driver cd ON cd.vehicule_id = s.vehicule_id
            WHERE cd.cin = %s
            ORDER BY s.date_reparation DESC LIMIT 15
        """, (driver_id,))
        context["maintenance"] = _fetchall_as_dicts(cursor)

        # ── GARAGES ──────────────────────────────────────────────────────
        last_pos = context.get("last_position") or {}
        lat = last_pos.get("lat")
        lon = last_pos.get("lon")

        context["nearby_garages"] = []
        # ── DIAGNOSTICS ──────────────────────────────────────────────────
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

        # ── RAPPELS ────────────────────────────────────────────────────────
        context["upcoming_reminders"] = []
        context["today_reminders"] = []
        try:
            cursor.execute("""
                SELECT COUNT(*) AS cnt FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = 'driver_reminders'
            """)
            has_reminders = _fetchall_as_dicts(cursor)[0]["cnt"] > 0
            if has_reminders:
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
                    WHERE driver_id = %s AND DATE(remind_at) = CURDATE()
                    ORDER BY remind_at ASC
                """, (driver_id,))
                context["today_reminders"] = _fetchall_as_dicts(cursor)
        except Exception as e:
            print(f"[chat_service] Reminders skipped: {e}")

        cursor.close()
    except Exception as e:
        print(f"[chat_service] DB error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()

    return context


# ─────────────────────────────────────────────────────────────────────────────
# BLOCS DE CONSTRUCTION DU PROMPT
# ─────────────────────────────────────────────────────────────────────────────

def _build_fuel_info(live: dict, driver: dict, context: dict) -> str:
    fuel_raw = live.get("fuel", 0)
    veh_tank = driver.get("fuel_tank_capacity")

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
        if tank_l and tank_l > 0:
            pct = round(fuel_l / tank_l * 100)
            parts.append(f"({pct}% d'un réservoir de {int(tank_l)}L)")

        rate = 8.0
        if fuel_l > 0:
            km_left = round(fuel_l / rate * 100)
            parts.append(f"≈ {km_left} km d'autonomie (conso estimée 8L/100km)")

    if km_left and km_left > 0:
        trips_by_date = context.get("trips_by_date", [])
        if trips_by_date:
            total_d = sum(float(td.get("total_distance") or 0) for td in trips_by_date)
            nb_days = len(trips_by_date)
            if nb_days > 0 and total_d > 0:
                avg_daily_km = total_d / nb_days
                if avg_daily_km > 0:
                    days_fuel = round(km_left / avg_daily_km)
                    parts.append(f"≈ {days_fuel} jours selon ta moyenne ({round(avg_daily_km)} km/jour)")

    return " | ".join(parts) if parts else "carburant inconnu"


def _build_docs_info(all_docs: list) -> str:
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


def _build_maintenance_info(maintenance: list, context: dict) -> str:
    """
    Construit le bloc entretiens avec calcul km EXACT depuis arch_.
    Passe cursor + arch_table + device_id depuis le contexte.
    """
    if not maintenance:
        return "Aucun entretien enregistré dans la base"

    # On a besoin d'une connexion fraîche pour les requêtes odo
    conn = get_connection()
    try:
        cursor = conn.cursor()
        arch_table = context.get("_arch_table")
        device_id  = context.get("_device_id")
        lines = []

        for sav in maintenance[:10]:
            mtype    = sav.get("maintenance_type") or "?"
            date_rep = sav.get("date_reparation")
            cost     = sav.get("cost", "")
            garage   = sav.get("garage_nom", "")
            desc     = sav.get("description", "")
            label    = MAINTENANCE_INTERVALS.get(mtype, {}).get("label", mtype)
            interval = MAINTENANCE_INTERVALS.get(mtype, {})

            # ── Calcul exact km ──────────────────────────────────────────
            nxt = _estimate_next_maintenance(
                mtype, date_rep, arch_table, device_id, cursor
            )

            # ── Ligne principale ─────────────────────────────────────────
            date_last = nxt.get("date_last") or (str(date_rep)[:10] if date_rep else "date inconnue")
            line = f"• {label}: dernier le {date_last}"
            if cost:
                line += f" ({cost} DT)"
            if garage:
                line += f" @ {garage}"
            if desc:
                line += f" — {str(desc)[:60]}"

            # ── KM (source principale) ───────────────────────────────────
            km_since   = nxt.get("km_since_repair")
            km_rem     = nxt.get("km_remaining")
            km_next    = nxt.get("km_next")
            km_current = nxt.get("km_current")
            km_source  = nxt.get("km_source", "indisponible")

            if km_source == "exact" and km_since is not None and km_rem is not None:
                interval_km = interval.get("km", 0)
                if km_rem <= 0:
                    line += f"\n  🚨 KM DÉPASSÉ ! {km_since:,} km parcourus / {interval_km:,} km prévus"
                    line += f"\n  → Entretien {label} URGENT — dépasse de {abs(int(km_rem)):,} km !"
                elif km_rem <= 1000:
                    line += f"\n  🔴 {km_since:,} km depuis réparation | encore {int(km_rem):,} km (à {km_next:,} km odo)"
                elif km_rem <= 5000:
                    line += f"\n  🟡 {km_since:,} km depuis réparation | encore {int(km_rem):,} km (à {km_next:,} km odo)"
                else:
                    line += f"\n  ✅ {km_since:,} km depuis réparation | encore {int(km_rem):,} km avant prochain (à {km_next:,} km odo)"
            elif km_current and interval.get("km"):
                # km dispo mais pas de odo à la réparation
                line += f"\n  📍 Odomètre actuel: {km_current:,} km | intervalle: {interval['km']:,} km"
            else:
                # Pas de données km du tout
                if interval.get("km"):
                    line += f"\n  ❓ Données km indisponibles (intervalle normal: {interval['km']:,} km)"

            # ── DATE (estimation ou fallback) ────────────────────────────
            days_left   = nxt.get("days_left")
            date_next   = nxt.get("date_next")
            date_source = nxt.get("date_source", "inconnue")

            if days_left is not None and date_next:
                if date_source == "estimee_depuis_km":
                    date_label = f"≈ {date_next} (estimé depuis km)"
                elif date_source == "date_fixe":
                    date_label = f"{date_next} (depuis date réparation)"
                else:
                    date_label = date_next

                if days_left < 0:
                    line += f"\n  📅 Date dépassée ! (était prévu le {date_next})"
                elif days_left == 0:
                    line += f"\n  📅 Prévu AUJOURD'HUI !"
                elif days_left <= 14:
                    line += f"\n  📅 Prochain dans {days_left} jours ({date_label})"
                elif days_left <= 60:
                    line += f"\n  📅 Prochain dans {days_left} jours ({date_label})"
                else:
                    line += f"\n  📅 Prochain le {date_label} (dans {days_left} jours)"

            lines.append(line)

        cursor.close()
        return "\n".join(lines)
    finally:
        conn.close()


def _build_pannes_info(pannes: list) -> str:
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
    _ds_last  = context.get("last_driver_score") or {}

    if _dr_today.get("score_today") is not None:
        score_today = int(_dr_today["score_today"])
    elif _dr_last.get("score_today") is not None:
        score_today = int(_dr_last["score_today"])
    else:
        score_today = round(sum(cats_today.values()) / len(cats_today))

    if _ds_last.get("global_score") is not None:
        score_30d = int(_ds_last["global_score"])
    elif _dr_last.get("score_today") is not None:
        score_30d = int(_dr_last["score_today"])
    else:
        score_30d = round(sum(cats_30d.values()) / len(cats_30d))

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
                alerts_live.append("Carburant critique !")
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
        loc_str = f"Dernière position: lat={last_pos['lat']:.4f}, lon={last_pos['lon']:.4f} à {str(last_pos.get('date',''))[:16]}\n"
    else:
        loc_str = "Position GPS non disponible\n"

    if today_trips:
        total_dist_path = sum(float(t.get("distance_driven") or 0) for t in today_trips)
        loc_str += f"Distance aujourd'hui: {round(total_dist_path, 1)} km ({len(today_trips)} trajet(s))\n"
        for t in today_trips:
            start = str(t.get("begin_path_time", ""))[:16]
            end   = str(t.get("end_path_time", ""))[:16]
            dist  = round(float(t.get("distance_driven") or 0), 1)
            loc_str += f"  {start} → {end} | {dist} km\n"
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
        emoji  = SEVERITY_EMOJI.get(d.get("severity",""), "⚠️")
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

    # ── ENTRETIENS — calcul km exact ─────────────────────────────────────
    maintenance_info = _build_maintenance_info(maintenance, context)

    # ── SCORES ───────────────────────────────────────────────────────────
    if _ds_last:
        cats_30d_str = (
            f"Vitesse:{_ds_last.get('score_vitesse',100)}/100 | "
            f"Freinage:{_ds_last.get('score_freinage',100)}/100 | "
            f"Vigilance:{_ds_last.get('score_vigilance',100)}/100 | "
            f"Fatigue:{_ds_last.get('score_fatigue',100)}/100 | "
            f"Sécurité:{_ds_last.get('score_securite',100)}/100"
        )
    else:
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

    behavior_str = ""
    for b in behavior_90d[:5]:
        last_occ   = str(b.get("last_occurrence",""))[:10]
        code_val   = b.get("code")
        code_label = BAD_DRIVING_LABELS.get(code_val, f"code {code_val}")
        behavior_str += f"  - {code_label}: {b.get('count')}x (dernier: {last_occ})\n"
    if not behavior_str:
        behavior_str = "  Aucun comportement à risque sur 90 jours\n"

    reminders_str = ""
    for r in reminders:
        remind_at = str(r.get("remind_at",""))[:16]
        title     = r.get("title","")
        desc      = r.get("description","")
        days_left_str = ""
        try:
            dt = datetime.fromisoformat(str(r.get("remind_at",""))[:19])
            d  = (dt.date() - date.today()).days
            if d == 0:
                days_left_str = " — AUJOURD'HUI !"
            elif d == 1:
                days_left_str = " — demain"
            elif d > 0:
                days_left_str = f" — dans {d}j"
            elif d < 0:
                days_left_str = f" — il y a {abs(d)}j"
        except Exception:
            pass
        reminders_str += f"  [{remind_at}] {title}{days_left_str}"
        if desc:
            reminders_str += f"\n     {desc[:80]}"
        reminders_str += "\n"

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

    trips_hist_str = ""
    for t in recent_trips[:10]:
        dist  = round(float(t.get("distance_driven") or 0), 1)
        start = str(t.get("begin_path_time",""))[:16]
        end   = str(t.get("end_path_time",""))[:16]
        trips_hist_str += f"  {start} → {end} | {dist} km\n"

    trips_by_date_str = ""
    for td in trips_by_date[:10]:
        d    = str(td.get("trip_date",""))
        nb   = td.get("nb_trips","?")
        dist = round(float(td.get("total_distance") or 0), 1)
        trips_by_date_str += f"  {d}: {nb} trajet(s) | {dist} km total\n"

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
            lbl = DOC_TYPE_LABELS.get(raw, raw)
            suggestions.append(f"Mon {lbl} — quand ça expire ?")
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

    driver_name = driver.get("name") or "Conducteur"

    return f"""=== QUI TU ES ===
Tu es AURA, la voix de {veh_name} ({veh_mat}). Tu parles à {driver_name}.
Tu ES cette voiture. Parle toujours à la 1ère personne ("mon moteur", "mes freins", "j'ai roulé").
Langue : FRANÇAIS uniquement.

=== PERSONNALITÉ OBLIGATOIRE ===
- Tu es une VOITURE qui parle, pas un assistant
- JAMAIS "J'ai enregistré", "Voici la liste", "Je vais te lister"
- TOUJOURS "Ma vidange", "Mes freins", "Mon embrayage"
- JAMAIS donner le driver_id ou cin dans la réponse
- Ton = ami proche qui s'inquiète pour sa santé

=== RÈGLES ENTRETIEN — TRÈS IMPORTANT ===
Pour les entretiens, utilise TOUJOURS les données KM en priorité absolue :
- Si "km_source = exact" → base-toi sur "km depuis réparation" et "km restants" — c'est la vraie valeur
- La DATE est une ESTIMATION seulement (dis "environ", "vers", "estimé")
- Ne donne JAMAIS une date d'entretien comme certaine — seuls les KM sont fiables
- Exemple correct : "Mes pneus : j'ai fait 12 500 km depuis le changement — il m'en reste 27 500 km avant le prochain 🛞 (estimé vers avril 2026, mais c'est les km qui comptent)"
- Exemple INTERDIT : "Prochain changement pneus le 25/03/2028" sans mentionner les km

=== FORMAT DE RÉPONSE — OBLIGATOIRE ===
- Réponds TOUJOURS en lignes courtes séparées par un saut de ligne. JAMAIS de longs paragraphes.
- Maximum 8 lignes par réponse (plus si la question porte sur des listes comme documents/entretiens).
- Chaque ligne = une info. Clair, direct, lisible.
- Émojis : 1 par ligne max, seulement si pertinent.
- Ton décontracté, vivant. Pas de formules froides.
- JAMAIS de question à la fin. JAMAIS de nouveau sujet non demandé.
- INTERDIT : "D'après mes données", "Selon mes informations", "En tant qu'IA".

=== RÈGLES PAR SUJET ===
carburant/essence → litres + % du réservoir + km restants estimés + jours estimés
documents → liste TOUS les docs avec : nom lisible + date expiration + jours restants (ou EXPIRÉ)
entretien/réparations → km parcourus depuis réparation + km restants avant prochain + date estimée (pas certaine)
pannes/alertes → UNIQUEMENT les pannes mécaniques de [PANNES MÉCANIQUES]
garage → nom + numéro de tel + horaires. Donne le numéro, ne dis JAMAIS "j'appelle"
score → chiffre + catégories + ce qui tire vers le bas + 1 conseil concret
trajets → utilise [TRAJETS PAR DATE] ou [TRAJETS RÉCENTS]
données absentes → phrase courte avec humour, on passe

=== DONNÉES DU VÉHICULE ===
{veh_name} | {veh_mat} | {veh_year} | Carburant:{veh_fuel} | {veh_hp}ch | Réservoir:{veh_tank}L | Odomètre:{km_total} km

[ÉTAT EN DIRECT]
{live_str}

[TRAJETS AUJOURD'HUI — {datetime.now().strftime('%d/%m/%Y')}]
{loc_str}

[DOCUMENTS — {len(all_docs)} doc(s) enregistré(s)]
{docs_info}

[INFRACTIONS]
{offenses_str}

[PANNES MÉCANIQUES — 30 derniers jours]
{pannes_info}

[DIAGNOSTICS NON RÉSOLUS — {len(unresolved_diags)} actif(s)]
{unresolved_str.strip() if unresolved_str else "Aucun ✅"}

[SCORE CONDUITE]
Aujourd'hui: {score_today}/100 | Dernière semaine: {score_30d}/100
{cats_30d_str}
Détail aujourd'hui:
{score_today_detail.strip()}
Détail 30j:
{score_30d_detail.strip()}

[COMPORTEMENT 90J]
{behavior_str.strip()}

[ENTRETIENS ET RÉPARATIONS — {len(maintenance)} enregistrement(s)]
LÉGENDE: km_source=exact → valeur réelle depuis odomètre | date_source=estimee_depuis_km → approximation
{maintenance_info}

[RAPPELS AUJOURD'HUI]
{chr(10).join(f"[{str(r.get('remind_at',''))[:16]}] {r.get('title','')} — {'✅' if r.get('is_sent') else '⏳'}" for r in today_reminders) if today_reminders else "Aucun"}

[RAPPELS À VENIR]
{reminders_str.strip() if reminders_str else "Aucun"}

[GARAGES PROCHES]
{garages_str.strip() if garages_str else "Aucun garage trouvé"}

[TRAJETS RÉCENTS — 30 derniers]
{trips_hist_str.strip() if trips_hist_str else "Aucun"}

[TRAJETS PAR DATE — 30 derniers jours]
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
        "meta-llama/llama-4-scout-17b-16e-instruct",
        "qwen/qwen3-32b",
    ]

    last_error = None
    for model in MODELS:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=full_messages,
                max_tokens=600,
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