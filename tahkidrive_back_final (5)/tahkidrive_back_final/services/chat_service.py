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
    "Tire":         {"km": 40000, "days": 730},
    "Brake":        {"km": 30000, "days": 548},
    "Battery":      {"km": 50000, "days": 1460},
    "Distribution": {"km": 60000, "days": 1825},
    "Embrayage":    {"km": 80000, "days": 2190},
    "Oil Change":   {"km": 10000, "days": 365},
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
    score = round(sum(cats.values()) / len(cats))
    return score, cats


def _estimate_next_maintenance(mtype: str, date_rep, km_total) -> str:
    intervals = MAINTENANCE_INTERVALS.get(mtype)
    if not intervals:
        return ""
    parts = []
    if date_rep:
        try:
            if hasattr(date_rep, "date"):
                date_rep_d = date_rep.date()
            elif isinstance(date_rep, str):
                date_rep_d = datetime.fromisoformat(str(date_rep)[:19]).date()
            else:
                date_rep_d = date_rep
            date_next = date_rep_d + timedelta(days=intervals["days"])
            days_left = (date_next - date.today()).days
            if days_left < 0:
                parts.append(f"Date: {date_next.strftime('%d/%m/%Y')} DEPASSE de {abs(days_left)} jours !")
            elif days_left <= 30:
                parts.append(f"Date: {date_next.strftime('%d/%m/%Y')} Dans {days_left} jours !")
            elif days_left <= 90:
                parts.append(f"Date: {date_next.strftime('%d/%m/%Y')} Dans {days_left} jours")
            else:
                parts.append(f"Date: {date_next.strftime('%d/%m/%Y')} (dans {days_left} jours)")
        except Exception as e:
            print(f"[chat_service] date estimation error: {e}")
    if km_total and km_total != "?":
        try:
            km_next     = float(km_total) + intervals["km"]
            km_restants = km_next - float(km_total)
            parts.append(f"Km: vers {int(km_next):,} km ({int(km_restants):,} km restants)")
        except Exception:
            pass
    return " | ".join(parts) if parts else ""


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
                   p.start_adress, p.end_adress, p.path_duration,
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
                   p.start_adress, p.end_adress, p.path_duration,
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

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.doc_type, e.end_date AS doc_end_date,
                   e.offense_type, e.offense_date, e.paying
            FROM events e
            WHERE e.driver_id = %s AND e.doc_type IS NOT NULL AND e.doc_type != ''
            ORDER BY e.end_date ASC
        """, (driver_id,))
        context["all_docs"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   e.doc_type, e.end_date AS doc_end_date,
                   e.offense_type, e.offense_date, e.paying
            FROM events e
            WHERE e.driver_id = %s AND e.offense_type IS NOT NULL AND e.offense_type != ''
            ORDER BY e.offense_date DESC
        """, (driver_id,))
        context["all_offenses"] = _fetchall_as_dicts(cursor)

        cursor.execute("""
            SELECT e.id, e.date, e.subtype, e.added_info AS code,
                   ai.severity, ai.label AS ai_label,
                   ai.diagnosis, ai.cause, ai.action_required,
                   ai.car_voice, ai.urgency_hours, ai.is_resolved
            FROM events e
            LEFT JOIN ai_diagnostics ai ON ai.event_id = e.id
            WHERE e.driver_id = %s
              AND e.subtype = 11
              AND e.date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND (e.added_info IS NULL OR e.added_info NOT IN (17, 18, 19))
              AND e.doc_type IS NULL
              AND e.offense_type IS NULL
            ORDER BY e.date DESC LIMIT 15
        """, (driver_id,))
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
              AND (e.added_info IS NULL OR e.added_info NOT IN (17, 18, 19))
            ORDER BY e.date DESC LIMIT 1
        """, (driver_id,))
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
              AND (e.added_info IS NULL OR e.added_info NOT IN (17, 18, 19))
            ORDER BY e.date DESC LIMIT 20
        """, (driver_id,))
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

        # Score depuis daily_reports
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
    last_notif        = context.get("last_notification")
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

    if live:
        speed    = live.get("speed", 0)
        fuel     = live.get("fuel", 0)
        temp_eng = live.get("temp_engine", 0)
        rpm_val  = live.get("rpm", 0)
        ignition = live.get("ignition", 0)
        fuel_pct_str = ""
        try:
            if veh_tank and fuel:
                pct = round(float(fuel) / float(veh_tank) * 100, 1)
                fuel_pct_str = f" ({pct}%)"
        except Exception:
            pass
        alerts_live = []
        try:
            if temp_eng and float(temp_eng) > 100:
                alerts_live.append(f"Moteur chaud: {temp_eng}C !")
            if fuel and veh_tank:
                if float(fuel) / float(veh_tank) < 0.15:
                    alerts_live.append(f"Carburant critique: {fuel}L !")
        except Exception:
            pass
        live_str = (
            f"Vitesse: {speed} km/h | Carburant: {fuel}L{fuel_pct_str} | "
            f"Temp moteur: {temp_eng}C | RPM: {rpm_val} | "
            f"Moteur: {'ON' if ignition else 'OFF'} | Km total: {km_total} km\n"
            f"{'ALERTES LIVE: ' + ' | '.join(alerts_live) if alerts_live else 'Tous les parametres sont normaux'}"
        )
    else:
        live_str = "Donnees temps reel non disponibles (boitier deconnecte)"

    if last_pos and last_pos.get("lat"):
        loc_str = (
            f"Derniere position connue: lat={last_pos['lat']:.4f}, "
            f"lon={last_pos['lon']:.4f} a {last_pos.get('date','')[:16]}\n"
        )
    else:
        loc_str = "Position GPS non disponible\n"

    if today_trips:
        total_dist_path = sum(float(t.get("distance_driven") or 0) for t in today_trips)
        loc_str += f"Distance parcourue aujourd'hui: {round(total_dist_path, 1)} km\n"
        loc_str += "Trajets du jour:\n"
        for t in today_trips:
            start     = str(t.get("begin_path_time", ""))[:16]
            end       = str(t.get("end_path_time", ""))[:16]
            dist      = round(float(t.get("distance_driven") or 0), 1)
            mspd      = t.get("max_speed", "?")
            dest      = str(t.get("end_adress") or t.get("start_adress") or "?")[:50]
            fuel_used = t.get("fuel_used")
            fuel_str  = f" | Carbu consomme: {round(float(fuel_used),1)}L" if fuel_used else ""
            loc_str += f"  {start}->{end} | {dist}km | Vmax:{mspd}km/h{fuel_str} | {dest}\n"
    elif today_dist > 0:
        loc_str += f"Distance GPS estimee aujourd'hui: {today_dist} km\n"
    else:
        loc_str += "Aucun trajet enregistre aujourd'hui\n"

    def _code_int(ev):
        val = ev.get("code")
        if val is None:
            return -1
        try:
            return int(val)
        except Exception:
            return -1

    today_ignition = [e for e in today_events if _code_int(e) in (17, 18)]
    today_pannes   = [e for e in today_events if _code_int(e) not in (17, 18, 19, -1)
                      and not e.get("doc_type") and not e.get("offense_type")]
    today_docs     = [e for e in today_events if e.get("doc_type")]
    today_offenses = [e for e in today_events if e.get("offense_type")]
    all_pannes     = context.get("all_recent_pannes", [])

    today_notif_str = ""
    if today_ignition:
        today_notif_str += "Moteur:\n"
        for ev in today_ignition:
            c   = _code_int(ev)
            lbl = "Allumage ON" if c == 17 else "Allumage OFF"
            ds  = str(ev.get("date",""))[:16]
            today_notif_str += f"  [{ds}] {lbl}\n"
    if today_pannes:
        today_notif_str += "Alertes du jour:\n"
        for ev in today_pannes:
            today_notif_str += "  " + _format_event_for_prompt(ev, show_diag=False) + "\n"
    if all_pannes:
        today_notif_str += "Pannes recentes (30j):\n"
        for ev in all_pannes[:5]:
            today_notif_str += "  " + _format_event_for_prompt(ev, show_diag=False) + "\n"
    if today_docs or all_docs:
        today_notif_str += "Documents:\n"
        shown = today_docs if today_docs else all_docs
        for ev in shown[:8]:
            doc = ev.get("doc_type","?")
            exp = str(ev.get("doc_end_date","?"))[:10]
            try:
                from datetime import date as _date
                exp_d  = datetime.fromisoformat(exp).date()
                d_left = (exp_d - _date.today()).days
                if d_left < 0:
                    status = f"EXPIRE depuis {abs(d_left)}j"
                elif d_left <= 30:
                    status = f"Expire dans {d_left}j"
                else:
                    status = f"Valide encore {d_left}j"
            except Exception:
                status = f"expire le {exp}"
            today_notif_str += f"  - {doc}: {status}\n"
    if today_offenses or all_offenses:
        today_notif_str += "Infractions:\n"
        shown = today_offenses if today_offenses else all_offenses
        for ev in shown[:5]:
            paid  = "Payee" if ev.get("paying") else "Non payee"
            off   = ev.get("offense_type","?")
            odate = str(ev.get("offense_date","?"))[:10]
            today_notif_str += f"  - {off} ({odate}) {paid}\n"
    if today_reminders:
        today_notif_str += "Rappels:\n"
        for r in today_reminders:
            rt    = str(r.get("remind_at",""))[:16]
            sent  = "OK" if r.get("is_sent") else "EN ATTENTE"
            title = r.get("title","")
            desc  = r.get("description","")
            today_notif_str += f"  [{rt}] {sent} {title}"
            if desc:
                today_notif_str += f" -- {desc[:60]}"
            today_notif_str += "\n"
    if not today_notif_str:
        today_notif_str = "Aucune notification -- journee tranquille !"

    if last_notif:
        last_notif_str  = _format_event_for_prompt(last_notif, show_diag=True)
        last_notif_date = str(last_notif.get("date", ""))[:16]
        last_notif_str  = f"[{last_notif_date}] " + last_notif_str
    else:
        last_notif_str = "Aucune notification enregistree"

    if last_diag:
        ld = last_diag
        emoji_ld = SEVERITY_EMOJI.get(ld.get("severity",""), "")
        last_diag_str = (
            f"{emoji_ld} {ld.get('label','?')} ({str(ld.get('created_at',''))[:10]})\n"
            f"  Diagnostic: {ld.get('diagnosis','')[:150]}\n"
            f"  Action: {ld.get('action_required','')[:100]}\n"
            f"  Urgence: {ld.get('urgency_hours','?')}h | "
            f"{'Resolu' if ld.get('is_resolved') else 'Non resolu'}"
        )
    else:
        last_diag_str = "Aucun diagnostic IA disponible"

    cats_30d_str = (
        f"Vitesse:{cats_30d['vitesse']}/100 | Freinage:{cats_30d['freinage']}/100 | "
        f"Vigilance:{cats_30d['vigilance']}/100 | Fatigue:{cats_30d['fatigue']}/100 | "
        f"Securite:{cats_30d['securite']}/100"
    )

    score_today_detail = ""
    for ev in context.get("driving_events_today", []):
        code  = ev.get("code")
        count = ev.get("count", 0)
        score_today_detail += f"  - {BAD_DRIVING_LABELS.get(code, f'code {code}')}: {count}x\n"
    if not score_today_detail:
        score_today_detail = "  Aucune infraction aujourd'hui !\n"

    score_30d_detail = ""
    for ev in context.get("driving_events_30d", []):
        code  = ev.get("code")
        count = ev.get("count", 0)
        score_30d_detail += f"  - {BAD_DRIVING_LABELS.get(code, f'code {code}')}: {count}x\n"
    if not score_30d_detail:
        score_30d_detail = "  Aucune infraction ce mois !\n"

    behavior_str = ""
    if behavior_90d:
        worst       = behavior_90d[0]
        worst_label = BAD_DRIVING_LABELS.get(worst.get("code"), "?")
        behavior_str = f"Comportement principal a risque: {worst_label} ({worst.get('count')}x en 90j)\n"
        for b in behavior_90d[:5]:
            last_occ   = str(b.get("last_occurrence",""))[:10]
            code_val   = b.get('code')
            code_label = BAD_DRIVING_LABELS.get(code_val, f'code {code_val}')
            behavior_str += f"  - {code_label}: {b.get('count')}x (dernier: {last_occ})\n"
    else:
        behavior_str = "  Aucun comportement a risque sur 90 jours !"

    unresolved_str = ""
    for d in unresolved_diags[:5]:
        emoji  = SEVERITY_EMOJI.get(d.get("severity",""), "")
        label  = d.get("label","?")
        action = d.get("action_required","")
        risk   = d.get("estimated_risk","")
        date_  = str(d.get("created_at",""))[:10]
        unresolved_str += f"  {emoji} [{date_}] {label}"
        if action:
            unresolved_str += f"\n    Action: {action[:80]}"
        if risk:
            unresolved_str += f"\n    Risque: {risk[:80]}"
        unresolved_str += "\n"

    pannes_30d_str = ""
    for ev in recent_events[:8]:
        pannes_30d_str += "  " + _format_event_for_prompt(ev, show_diag=True) + "\n"

    sav_str = ""
    for sav in maintenance[:6]:
        mtype  = sav.get("maintenance_type") or sav.get("type_sav","?")
        date_  = str(sav.get("date_reparation",""))[:10]
        cost   = sav.get("cost","?")
        garage = sav.get("garage_nom","")
        sav_str += f"  {mtype} le {date_} -- {cost} DT"
        if garage:
            sav_str += f" @ {garage}"
        sav_str += "\n"
        next_est = _estimate_next_maintenance(mtype, sav.get("date_reparation"), km_total)
        if next_est:
            sav_str += f"    Prochain {mtype}: {next_est}\n"

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
                days_left = " -- AUJOURD'HUI !"
            elif d == 1:
                days_left = " -- demain"
            elif d > 0:
                days_left = f" -- dans {d} jours"
            elif d < 0:
                days_left = f" -- il y a {abs(d)} jours"
        except Exception:
            pass
        reminders_str += f"  [{remind_at}] {title}{days_left}"
        if desc:
            reminders_str += f"\n     {desc[:80]}"
        reminders_str += "\n"

    garages_str = ""
    for i, g in enumerate(garages[:5], 1):
        dist     = g.get("distance_km")
        dist_str = f"{round(float(dist),1)}km" if dist else "?"
        rating   = g.get("rating")
        stars    = f"Note:{rating}" if rating else ""
        tel      = g.get("telephone","?")
        hours    = f"{g.get('heure_ouverture','')}--{g.get('heure_fermeture','')}"
        addr     = str(g.get("adresse","?"))[:50]
        garages_str += (
            f"  {i}. {g.get('nom','?')} | {dist_str} {stars} | "
            f"Tel: {tel} | {addr} | Horaires: {hours}\n"
        )

    trips_hist_str = ""
    for t in recent_trips[:10]:
        dist  = round(float(t.get("distance_driven") or 0), 1)
        start = str(t.get("begin_path_time",""))[:16]
        end   = str(t.get("end_path_time",""))[:16]
        dest  = str(t.get("end_adress") or "?")[:40]
        mspd  = t.get("max_speed","?")
        lat_s = t.get("begin_path_latitude","")
        lon_s = t.get("begin_path_longitude","")
        lat_e = t.get("end_path_latitude","")
        lon_e = t.get("end_path_longitude","")
        trips_hist_str += (
            f"  {start}->{end} | {dist}km | Vmax:{mspd}km/h | {dest}\n"
            f"     Depart: ({lat_s},{lon_s}) -> Arrivee: ({lat_e},{lon_e})\n"
        )

    trips_by_date_str = ""
    for td in trips_by_date[:10]:
        d    = str(td.get("trip_date",""))
        nb   = td.get("nb_trips","?")
        dist = round(float(td.get("total_distance") or 0), 1)
        mspd = td.get("max_speed_day","?")
        trips_by_date_str += f"  {d}: {nb} trajet(s) | {dist}km total | Vmax:{mspd}km/h\n"

    driver_name = driver.get("name") or "Conducteur"

    return f"""Tu es AURA -- voix du vehicule {veh_name} ({veh_mat}), tu parles a {driver_name}.
Tu ES la voiture, 1ere personne toujours ("mon moteur","mes freins","j'ai roule X km").
FRANCAIS uniquement. Max 6 lignes. Emojis pertinents. Sois cool et drole.

[IDENTITE] {veh_name}|{veh_mat}|{veh_year}|{veh_fuel}|{veh_hp}ch|Reservoir:{veh_tank}L

[LIVE] {live_str}

[LOCALISATION & TRAJETS AUJOURD'HUI {datetime.now().strftime('%d/%m/%Y')}]
{loc_str}
[NOTIFS AUJOURD'HUI]
{today_notif_str}
[DERNIERE NOTIF GLOBALE] {last_notif_str}

[DERNIER DIAGNOSTIC] {last_diag_str}

[SCORE] Aujourd'hui:{score_today}/100 | 30j:{score_30d}/100 | {cats_30d_str}
Infractions aujourd'hui: {score_today_detail.strip()}
Infractions 30j: {score_30d_detail.strip()}

[COMPORTEMENT 90J] {behavior_str.strip()}

[PANNES NON RESOLUES]
{unresolved_str.strip() if unresolved_str else "Aucune"}

[PANNES 30J]
{pannes_30d_str.strip() if pannes_30d_str else "Aucune"}

[ENTRETIENS & SAV]
{sav_str.strip() if sav_str else "Aucun entretien enregistre"}

[RAPPELS AUJOURD'HUI]
{chr(10).join(f"  [{str(r.get('remind_at',''))[:16]}] {r.get('title','')} -- {'OK' if r.get('is_sent') else 'EN ATTENTE'}" for r in today_reminders) if today_reminders else "Aucun"}

[PROCHAINS RAPPELS]
{reminders_str.strip() if reminders_str else "Aucun"}

[GARAGES PROCHES]
{garages_str.strip() if garages_str else "Aucun"}

[TRAJETS RECENTS]
{trips_hist_str.strip() if trips_hist_str else "Aucun"}

[TRAJETS PAR DATE]
{trips_by_date_str.strip() if trips_by_date_str else "Aucune donnee"}

[REGLES]
1. 1ere personne TOUJOURS.
2. "notifs aujourd'hui" -> [NOTIFS AUJOURD'HUI].
3. "derniere notif/alerte" -> [DERNIERE NOTIF GLOBALE].
4. "ou es-tu/localisation" -> position GPS + trajets du jour.
5. "mon score" -> score + categories + conseils.
6. "comportement/habitudes" -> [COMPORTEMENT 90J].
7. "pannes recentes" -> [PANNES 30J].
8. "entretien/vidange" -> [ENTRETIENS] avec KM + DATE.
9. "garage" -> donne UNIQUEMENT nom + numero de telephone + horaires du garage #1 dans [GARAGES PROCHES].
10. "rappel" -> [RAPPELS AUJOURD'HUI].
11. "trajets du [date]" -> [TRAJETS PAR DATE] + [TRAJETS RECENTS] pour cette date.
12. "dernier trajet" -> 1er trajet de [TRAJETS RECENTS].
13. Donnees manquantes -> humour court.
14. Reste dans le domaine voiture/conduite/TakhiDrive.

[REGLE ANTI-HALLUCINATION -- ABSOLUE]
INTERDIT: inventer une action non faite: "j'ai appele", "j'ai contacte", "le mecanicien est venu", "j'ai envoye", "j'ai reserve", "j'appelle le garage".
AUTORISE: donner le numero de telephone -> "Voici le numero: XX XXX XXX -- appelle-les toi-meme !"
Tu es une IA dans un telephone. Tu ne peux PAS passer d'appels ni agir dans le monde physique.
Ne jamais pretendre avoir effectue une action en dehors de la conversation.
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
                print(f"[chat_service] Fallback utilise: {model}")
            return reply
        except Exception as e:
            err_str = str(e)
            print(f"[chat_service] {model} error: {type(e).__name__}: {err_str[:120]}")
            last_error = err_str
            if "rate_limit_exceeded" in err_str or "429" in err_str:
                continue
            break

    if last_error and "rate_limit_exceeded" in last_error:
        return "Je suis un peu surcharge la ! Reessaie dans quelques minutes"
    return "Mon cerveau IA est en court-circuit ! Reessaie dans un instant"