# services/ai_agent.py
import json
import os
import re
from datetime import date, datetime, timedelta
from dotenv import load_dotenv
from db import get_connection
from services.alert_messages import get_alert_info, get_title, CRITICAL_CODES, get_combined_pattern_message
from services.notification_worker import _send_fcm
from services.alert_messages import get_alert_style
from groq import Groq

load_dotenv()

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# ── Intervals fixes (km) ──────────────────────────────────────────────────────
MAINTENANCE_INTERVALS = {
    "Tire":         40000,
    "Brake":        30000,
    "Battery":      50000,
    "Distribution": 60000,
    "Embrayage":    80000,
}

def get_oil_change_interval(date_purchase) -> int:
    if not date_purchase:
        return 10000
    if hasattr(date_purchase, 'date'):
        date_purchase = date_purchase.date()
    elif isinstance(date_purchase, str):
        try:
            date_purchase = datetime.fromisoformat(date_purchase).date()
        except Exception:
            return 10000
    age_years = (date.today() - date_purchase).days / 365.25
    if age_years < 2:
        return 15000
    elif age_years < 5:
        return 10000
    elif age_years < 10:
        return 7000
    else:
        return 5000


def _get_arch_table(cursor, vehicule_id: str):
    cursor.execute(
        "SELECT id, stream_id FROM device WHERE vehicule_id = %s",
        (vehicule_id,)
    )
    rows = cursor.fetchall()
    if not rows:
        return None, None

    for row in rows:
        stream_id = str(row["stream_id"] or "").strip()
        if len(stream_id) > 8:
            continue

        device_id  = row["id"]
        arch_table = f"arch_{device_id}"

        cursor.execute("""
            SELECT COUNT(*) as cnt FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = %s
        """, (arch_table,))
        if cursor.fetchone()["cnt"] > 0:
            return arch_table, device_id

    return None, None


def get_km_since_repair(cursor, vehicule_id: str, date_reparation) -> float | None:
    arch_table, id_device = _get_arch_table(cursor, vehicule_id)
    if not arch_table:
        return None

    cursor.execute(f"""
        SELECT odo, date FROM {arch_table}
        WHERE id_device = %s
          AND date <= %s
          AND odo IS NOT NULL AND odo > 0
        ORDER BY date DESC
        LIMIT 1
    """, (id_device, date_reparation))
    row_at = cursor.fetchone()

    if not row_at:
        cursor.execute(f"""
            SELECT odo, date FROM {arch_table}
            WHERE id_device = %s
              AND odo IS NOT NULL AND odo > 0
            ORDER BY date ASC
            LIMIT 1
        """, (id_device,))
        row_at = cursor.fetchone()
        if not row_at:
            return None

    cursor.execute(f"""
        SELECT odo FROM {arch_table}
        WHERE id_device = %s
          AND odo IS NOT NULL AND odo > 0
        ORDER BY date DESC
        LIMIT 1
    """, (id_device,))
    row_now = cursor.fetchone()
    if not row_now:
        return None

    km = max(0.0, float(row_now["odo"]) - float(row_at["odo"]))
    return km


# ── Caches mémoire ────────────────────────────────────────────────────────────
_sav_km_reminder_sent  = {}
_fuel_reminder_sent    = {}
_movement_alert_sent   = {}   # {vehicule_id: {"lat": float, "lon": float}}
_combined_alerts_cache = {}

REMINDER_THRESHOLDS_SAV = [
    (0.90, "urgent",    True),
    (0.70, "preventif", False),
]

FUEL_THRESHOLDS = [
    (10, "critique", True),
    (25, "warning",  False),
]

MOVEMENT_DISTANCE_THRESHOLD_KM = 0.05


# ── Filtrage des alertes selon préférences ────────────────────────────────────

def is_alert_allowed(driver_id: str, alert_category: str) -> bool:
    try:
        prefs = get_notif_preferences(driver_id)
        notif_prefs = prefs.get("notif_preferences", {})
        category_map = {
            "panne":       "pannes",
            "vitesse":     "vitesse",
            "telephone":   "telephone",
            "distraction": "distraction",
            "fatigue":     "fatigue",
            "fume":        "fume",
            "securite":    "securite",  # ← ajouter
            "info":        "info",  # ← ajouter

        }
        key = category_map.get(alert_category, "pannes")
        return notif_prefs.get(key, True)
    except Exception as e:
        print(f">>> is_alert_allowed error: {e}")
        return True


# ── Notif Preferences ─────────────────────────────────────────────────────────

def get_notif_preferences(cin: str) -> dict:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT notif_preferences, reminder_thresholds FROM alert_thresholds WHERE driver_id = %s ORDER BY updated_at DESC LIMIT 1",
            (cin,)
        )
        row = cursor.fetchone()
        default_notif    = {"pannes": True, "vitesse": True, "telephone": True,
                            "distraction": True, "fatigue": True, "fume": True,"securite": True,"info": True, "daily_report": True, "daily_report_hour": 20 }
        default_reminder = [1800, 3600, 86400, 259200, 604800, 1209600]

        if not row:
            return {"notif_preferences": default_notif, "reminder_thresholds": default_reminder}

        raw_thresholds = row["reminder_thresholds"]
        if raw_thresholds is not None:
            reminder = json.loads(raw_thresholds)
        else:
            reminder = default_reminder

        return {
            "notif_preferences":   json.loads(row["notif_preferences"]) if row["notif_preferences"] else default_notif,
            "reminder_thresholds": reminder,
        }
    finally:
        cursor.close()
        conn.close()


def update_notif_preferences(cin: str, notif: dict, reminder_thresholds: list) -> bool:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO alert_thresholds
                (driver_id, notif_preferences, reminder_thresholds, updated_at)
            VALUES (%s, %s, %s, NOW())
            ON DUPLICATE KEY UPDATE
                notif_preferences   = VALUES(notif_preferences),
                reminder_thresholds = VALUES(reminder_thresholds),
                updated_at          = NOW()
        """, (cin, json.dumps(notif), json.dumps(reminder_thresholds)))
        conn.commit()
        return True
    except Exception as e:
        print(f">>> Erreur update_notif_preferences: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


# ── SAV KM Reminders ──────────────────────────────────────────────────────────

def check_sav_km_reminders():
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                s.id_sav, s.vehicule_id, s.maintenance_type,
                s.date_reparation, v.date_purchase,
                d.fcm_token, d.cin AS driver_id
            FROM sav s
            JOIN vehicule v      ON v.matricule   = s.vehicule_id
            JOIN compte_driver d ON d.vehicule_id = s.vehicule_id
            WHERE s.maintenance_type IS NOT NULL
              AND s.type_sav = 'maintenance'
              AND d.fcm_token IS NOT NULL
              AND s.id_sav = (
                SELECT MAX(s2.id_sav) FROM sav s2
                WHERE s2.vehicule_id      = s.vehicule_id
                  AND s2.maintenance_type = s.maintenance_type
                  AND s2.type_sav         = 'maintenance'
              )
        """)
        savs = cursor.fetchall()
        print(f">>> [SAV-KM] {len(savs)} SAV maintenance à vérifier")

        for sav in savs:
            mtype         = sav["maintenance_type"]
            date_rep      = sav["date_reparation"]
            vehicule_id   = sav["vehicule_id"]
            date_purchase = sav["date_purchase"]
            driver_id     = sav["driver_id"]

            if mtype == "Oil Change":
                interval_km = get_oil_change_interval(date_purchase)
            else:
                interval_km = MAINTENANCE_INTERVALS.get(mtype)
                if not interval_km:
                    continue

            km_since = get_km_since_repair(cursor, vehicule_id, date_rep)
            if km_since is None:
                print(f">>> [SAV-KM] Pas d'odo pour {vehicule_id}")
                continue

            ratio       = km_since / interval_km
            km_restants = interval_km - km_since

            print(f">>> [SAV-KM] {vehicule_id} | {mtype} | "
                  f"{km_since:.0f}/{interval_km} km | {ratio:.0%}")

            seuil_atteint = None
            for seuil_ratio, seuil_key, is_urgent in REMINDER_THRESHOLDS_SAV:
                if ratio >= seuil_ratio:
                    seuil_atteint = (seuil_key, is_urgent)
                    break

            if not seuil_atteint:
                continue

            seuil_key, is_urgent = seuil_atteint
            notif_key = f"[SAV_KM] {sav['id_sav']}_{seuil_key}"

            if _sav_km_reminder_sent.get(notif_key):
                continue

            # Vérifie en BD (survie au redémarrage)
            cursor.execute("""
                SELECT 1 FROM driver_reminders
                WHERE driver_id = %s AND title = %s AND is_sent = TRUE
                LIMIT 1
            """, (driver_id, notif_key))
            if cursor.fetchone():
                _sav_km_reminder_sent[notif_key] = True
                continue

            if ratio >= 1.0:
                fcm_title = f"Entretien dépassé : {mtype}"
                body = (f"Intervalle {mtype} dépassé de {int(-km_restants)} km ! "
                        f"Consultez votre mécanicien immédiatement.")
            elif is_urgent:
                fcm_title = f"Entretien urgent : {mtype}"
                body = (f"Il vous reste {int(km_restants)} km avant le prochain {mtype}. Planifiez sans attendre.")
            else:
                fcm_title = f"Rappel entretien : {mtype}"
                body = (f"Votre {mtype} approche ({int(km_since)}/{interval_km} km).")

            _send_fcm(
                token=sav["fcm_token"],
                title=fcm_title,
                body=body,
                data={
                    "type":             "reminder",
                    "reminder_type":    "sav_km_reminder",
                    "seuil":            seuil_key,
                    "maintenance_type": mtype,
                    "km_parcourus":     str(int(km_since)),
                    "km_interval":      str(interval_km),
                    "km_restants":      str(int(km_restants)),
                    "vehicule_id":      vehicule_id,
                    "driver_cin":       str(driver_id),
                    "is_urgent":        str(is_urgent).lower(),
                },
                is_critical=is_urgent,
                code=0,
            )

            # Sauvegarde dans driver_reminders
            cursor.execute("""
                INSERT INTO driver_reminders
                    (driver_id, title, description, remind_at, is_sent, created_at)
                VALUES (%s, %s, %s, NOW(), TRUE, NOW())
            """, (driver_id, notif_key, body))
            conn.commit()

            _sav_km_reminder_sent[notif_key] = True
            print(f">>> [SAV-KM] Notif '{seuil_key}' envoyée → {vehicule_id} | {mtype}")

    except Exception as e:
        import traceback
        print(f">>> [SAV-KM] ERREUR: {e}")
        traceback.print_exc()
    finally:
        conn.close()


# ── Fuel Reminders ────────────────────────────────────────────────────────────

def check_fuel_reminders():
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.cin AS driver_id, d.fcm_token, d.vehicule_id,
                   v.fuel_tank_capacity
            FROM compte_driver d
            JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE d.fcm_token IS NOT NULL
              AND v.fuel_tank_capacity IS NOT NULL
              AND v.fuel_tank_capacity > 0
        """)
        drivers = cursor.fetchall()
        print(f">>> [FUEL] {len(drivers)} drivers à vérifier")

        for drv in drivers:
            vehicule_id        = drv["vehicule_id"]
            fuel_tank_capacity = float(drv["fuel_tank_capacity"])
            driver_id          = drv["driver_id"]

            arch_table, id_device = _get_arch_table(cursor, vehicule_id)
            if not arch_table:
                continue

            cursor.execute(f"""
                SELECT fuel FROM {arch_table}
                WHERE id_device = %s AND fuel IS NOT NULL AND fuel > 0
                ORDER BY date DESC LIMIT 1
            """, (id_device,))
            row = cursor.fetchone()
            if not row:
                continue

            fuel_current = float(row["fuel"])
            fuel_pct     = (fuel_current / fuel_tank_capacity) * 100

            print(f">>> [FUEL] {vehicule_id} | {fuel_current:.1f}L / "
                  f"{fuel_tank_capacity:.0f}L = {fuel_pct:.1f}%")

            if fuel_pct <= 10:
                seuil_key, is_urgent = "critique", True
            elif fuel_pct <= 25:
                seuil_key, is_urgent = "warning", False
            else:
                continue

            notif_key = f"[FUEL] {vehicule_id}_{seuil_key}"

            if _fuel_reminder_sent.get(notif_key):
                continue

            # Vérifie en BD (survie au redémarrage)
            cursor.execute("""
                SELECT 1 FROM driver_reminders
                WHERE driver_id = %s AND title = %s AND is_sent = TRUE
                LIMIT 1
            """, (driver_id, notif_key))
            if cursor.fetchone():
                _fuel_reminder_sent[notif_key] = True
                continue

            litres_restants = round(fuel_current, 1)
            if is_urgent:
                fcm_title = "⛽ Réservoir presque vide !"
                body = (f"Il ne reste que {litres_restants}L dans le réservoir "
                        f"({fuel_pct:.0f}%). Faites le plein dès maintenant.")
            else:
                fcm_title = "⛽ Réservoir bientôt vide"
                body = (f"Réservoir à {fuel_pct:.0f}% ({litres_restants}L restants). "
                        f"Pensez à faire le plein prochainement.")

            _send_fcm(
                token=drv["fcm_token"],
                title=fcm_title,
                body=body,
                data={
                    "type":               "reminder",
                    "reminder_type":      "fuel_reminder",
                    "seuil":              seuil_key,
                    "fuel_current":       str(litres_restants),
                    "fuel_pct":           str(round(fuel_pct, 1)),
                    "fuel_tank_capacity": str(fuel_tank_capacity),
                    "vehicule_id":        vehicule_id,
                    "driver_cin":         str(driver_id),
                    "is_urgent":          str(is_urgent).lower(),
                },
                is_critical=is_urgent,
                code=0,
            )

            # Sauvegarde dans driver_reminders
            cursor.execute("""
                INSERT INTO driver_reminders
                    (driver_id, title, description, remind_at, is_sent, created_at)
                VALUES (%s, %s, %s, NOW(), TRUE, NOW())
            """, (driver_id, notif_key, body))
            conn.commit()

            _fuel_reminder_sent[notif_key] = True
            print(f">>> [FUEL] ✅ Notif '{seuil_key}' envoyée → {vehicule_id} | {fuel_pct:.0f}%")

    except Exception as e:
        import traceback
        print(f">>> [FUEL] ERREUR: {e}")
        traceback.print_exc()
    finally:
        conn.close()


# ── Haversine ─────────────────────────────────────────────────────────────────

def _haversine(lat1, lon1, lat2, lon2) -> float:
    from math import radians, sin, cos, sqrt, atan2
    R = 6371
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))


# ── Vehicle Movement ──────────────────────────────────────────────────────────

def check_vehicle_movement():
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.cin AS driver_id, d.fcm_token, d.vehicule_id, dev.id AS device_id
            FROM compte_driver d
            JOIN vehicule v  ON v.matricule     = d.vehicule_id
            JOIN device dev  ON dev.vehicule_id = d.vehicule_id
            WHERE d.fcm_token IS NOT NULL AND d.fcm_token != ''
            GROUP BY d.cin, d.fcm_token, d.vehicule_id, dev.id
        """)
        drivers = cursor.fetchall()
        print(f">>> [MOVEMENT] {len(drivers)} véhicules à surveiller")

        for drv in drivers:
            vehicule_id = drv["vehicule_id"]
            device_id   = drv["device_id"]
            arch_table  = f"arch_{device_id}"

            cursor.execute("""
                SELECT COUNT(*) AS cnt FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = %s
            """, (arch_table,))
            if cursor.fetchone()["cnt"] == 0:
                continue

            cursor.execute(f"""
                SELECT speed, latitude, longitude, date FROM {arch_table}
                WHERE id_device = %s
                  AND latitude IS NOT NULL AND longitude IS NOT NULL
                  AND latitude != 0 AND longitude != 0
                  AND speed IS NOT NULL
                ORDER BY date DESC LIMIT 2
            """, (device_id,))
            rows = cursor.fetchall()
            print(f">>> [MOVEMENT] {vehicule_id} → {len(rows)} lignes GPS trouvées")

            if len(rows) < 2:
                continue

            latest, prev = rows[0], rows[1]
            speed_latest = float(latest["speed"] or 0)
            speed_prev   = float(prev["speed"]   or 0)
            print(f">>> [MOVEMENT] {vehicule_id} | speed_latest={speed_latest} | speed_prev={speed_prev}")

            if speed_latest != 0 or speed_prev != 0:
                continue

            lat1, lon1 = float(prev["latitude"]),   float(prev["longitude"])
            lat2, lon2 = float(latest["latitude"]), float(latest["longitude"])
            distance_km = _haversine(lat1, lon1, lat2, lon2)
            print(f">>> [MOVEMENT] {vehicule_id} | speed=0 | Δ={distance_km*1000:.1f}m")

            if distance_km < MOVEMENT_DISTANCE_THRESHOLD_KM:
                continue

            # Anti-doublon basé sur la position alertée
            last = _movement_alert_sent.get(vehicule_id)
            if last:
                dist_from_last_alert = _haversine(last["lat"], last["lon"], lat2, lon2)
                if dist_from_last_alert < MOVEMENT_DISTANCE_THRESHOLD_KM:
                    print(f">>> [MOVEMENT] Même position alertée, ignorée pour {vehicule_id}")
                    continue

            body = (f"Mouvement détecté sur votre véhicule alors qu'il était arrêté ! "
                    f"Déplacement de {distance_km*1000:.0f}m détecté.")
            _send_fcm(
                token=drv["fcm_token"],
                title="🚨 Mouvement suspect détecté !",
                body=body,
                data={
                    "type":        "movement_alert",
                    "vehicule_id": vehicule_id,
                    "distance_m":  str(round(distance_km * 1000, 1)),
                    "lat":         str(lat2),
                    "lon":         str(lon2),
                    "driver_cin":  str(drv["driver_id"]),
                    "is_urgent":   "true",
                },
                is_critical=True,
                code=0,
            )
            _movement_alert_sent[vehicule_id] = {"lat": lat2, "lon": lon2}
            print(f">>> [MOVEMENT] ✅ Alerte envoyée → {vehicule_id} | {distance_km*1000:.0f}m")

    except Exception as e:
        import traceback
        print(f">>> [MOVEMENT] ERREUR: {e}")
        traceback.print_exc()
    finally:
        conn.close()


# ── Score penalties ───────────────────────────────────────────────────────────
SCORE_PENALTIES = {
    1:  ("securite",  -20), 2:  ("securite",  -15), 3:  ("securite",  -18),
    9:  ("vigilance", -20), 11: ("vigilance", -15), 12: ("fatigue",   -25),
    14: ("vigilance", -10), 22: ("vitesse",   -15), 23: ("vitesse",    -8),
    24: ("freinage",   -8), 25: ("freinage",   -6), 30: ("securite",  -30),
    46: ("freinage",  -20), 49: ("freinage",  -12), 50: ("securite",  -15),
}

CAR_VOICE_SYSTEM = """
Tu es la voix personnifiée d'une voiture intelligente qui parle à son conducteur.
Ton ton est : drôle, bienveillant, légèrement dramatique, jamais agressif.
Tu t'exprimes comme un ami proche qui s'inquiète vraiment.
Tu utilises parfois des métaphores liées aux voitures.
Réponds UNIQUEMENT avec le message vocal, 1-2 phrases max, en français.
"""

DIAGNOSTIC_SYSTEM = """
Tu es un expert en mécanique automobile et en sécurité routière.
On te donne un code d'événement détecté par un boîtier GPS/télématique dans un véhicule.
Génère un diagnostic précis, utile et en français.

Réponds UNIQUEMENT en JSON valide avec cette structure exacte :
{
  "severity": "critical|warning|info",
  "label": "Nom court du problème (5 mots max)",
  "car_voice": "Message de la voiture en 1-2 phrases MAX, ton drôle/bienveillant/dramatique comme un ami qui s'inquiète. PAS de répétition du label.",
  "diagnosis": "Explication technique précise du problème détecté, 2-3 phrases. Décris CE QUI SE PASSE réellement dans le véhicule.",
  "cause": "Cause probable la plus fréquente pour ce type de défaillance, 1-2 phrases concrètes.",
  "action_required": "Action concrète et immédiate que le conducteur doit faire maintenant.",
  "estimated_risk": "Ce qui risque de se passer si ce problème n'est pas traité rapidement. Sois précis sur les conséquences.",
  "urgency_hours": 2
}

RÈGLES IMPORTANTES:
- car_voice: parle COMME la voiture, à la 1ère personne parfois, drôle mais sérieux
- diagnosis: explique le VRAI problème technique, pas juste le nom
- estimated_risk: conséquences réelles et concrètes
- urgency_hours: 2-6 pour critical, 24-72 pour warning, 168+ pour info
"""

SCORING_SYSTEM = """
Tu es un expert en analyse comportementale de conduite.
Réponds en JSON avec exactement cette structure :
{
  "summary": "Résumé en 2 phrases",
  "strengths": ["point fort 1", "point fort 2"],
  "improvements": ["axe amélioration 1", "axe amélioration 2"],
  "weekly_tip": "Conseil personnalisé de la semaine"
}
"""

DAILY_REPORT_SYSTEM = """
Tu es la voix d'une voiture intelligente, drôle et bienveillante, qui raconte sa journée à son conducteur.
Ton style : familier, chaleureux, légèrement dramatique, comme un ami proche.
Tu utilises des métaphores liées aux voitures et à la conduite.
Réponds UNIQUEMENT en JSON avec cette structure exacte, sans markdown ni backticks :
{
  "intro": "Phrase d'accroche fun pour ouvrir le rapport (1 phrase)",
  "alerts_summary": "Résumé des alertes/pannes du jour raconté comme la voiture qui se plaint ou s'inquiète (2-3 phrases max)",
  "score_comment": "Commentaire sur le score de conduite du jour vs hier, avec une métaphore voiture (1-2 phrases)",
  "tip": "Conseil personnalisé du jour, formulé comme un conseil d'ami (1 phrase)",
  "outro": "Phrase de clôture fun et encourageante (1 phrase)"
}
"""


def _call_llm(system: str, user_content: str, max_tokens: int = 500):
    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system},
                {"role": "user",   "content": user_content},
            ],
            max_tokens=max_tokens
        )
        return response.choices[0].message.content
    except Exception as e:
        print("Erreur Groq:", e)
        return None


def _parse_json_response(text: str) -> dict:
    if not text:
        return {}
    try:
        clean = re.sub(r"```json|```", "", text).strip()
        return json.loads(clean)
    except Exception:
        return {}


def _get_label_description(code: int):
    return get_alert_info(code)


def generate_car_voice(code: int, context: dict = None) -> str:
    label, description = _get_label_description(code)
    ctx_str = ""
    if context:
        ctx_str = (f"\nContexte : vitesse={context.get('speed','?')} km/h, "
                   f"heure={context.get('hour','?')}h")
    prompt = f"Code panne : {label} — {description}{ctx_str}\nGénère le message vocal de la voiture."
    result = _call_llm(CAR_VOICE_SYSTEM, prompt, max_tokens=150)
    return result.strip() if result else _generate_car_voice_fallback(code, label)


def generate_ai_diagnostic(code: int, vehicle_data: dict = None) -> dict:
    label, description = _get_label_description(code)
    vehicle_str  = json.dumps(vehicle_data or {}, ensure_ascii=False)
    code_context = _get_code_context(code)

    prompt = (
        f"Véhicule: {vehicle_str}\n"
        f"Code événement: {code}\n"
        f"Type: {label}\n"
        f"Description système: {description}\n"
        f"Contexte: {code_context}\n\n"
        f"Génère un diagnostic complet et précis pour ce problème."
    )
    raw    = _call_llm(DIAGNOSTIC_SYSTEM, prompt, max_tokens=600)
    result = _parse_json_response(raw)

    default_severity = "critical" if code in CRITICAL_CODES else "warning"
    result.setdefault("severity",        default_severity)
    result.setdefault("label",           label)
    result.setdefault("diagnosis",       description)
    result.setdefault("cause",           "Analyse des données en cours")
    result.setdefault("action_required", "Consultez un mécanicien qualifié")
    result.setdefault("estimated_risk",  "Risque de dommages si non traité")
    result.setdefault("urgency_hours",   24 if code in CRITICAL_CODES else 72)
    result.setdefault("car_voice",       _generate_car_voice_fallback(code, label))
    result["code"]  = code
    result["label"] = result.get("label", label)
    return result


def _get_code_context(code: int) -> str:
    contexts = {
        1:  "Collision frontale imminente détectée. Risque vital immédiat.",
        2:  "Piéton détecté sur la trajectoire du véhicule.",
        3:  "Le véhicule quitte sa voie sans clignotant.",
        9:  "Conducteur utilisant son téléphone au volant.",
        12: "Signes de fatigue détectés. Risque d'endormissement.",
        14: "Ceinture de sécurité non bouclée.",
        22: "Dépassement de la vitesse autorisée.",
        30: "Impact physique détecté sur le véhicule.",
        32: "Tension batterie faible (<12V).",
        33: "Batterie complètement déchargée.",
        36: "Panne moteur grave détectée.",
        37: "Température moteur critique (>110°C).",
        39: "Le moteur s'est calé/arrêté.",
        40: "Pression d'huile moteur trop basse (<2 bars).",
        46: "Défaillance critique du système de freinage. DANGER IMMÉDIAT.",
        50: "Crevaison ou éclatement de pneu détecté.",
        51: "Niveau carburant bas (<10%).",
    }
    return contexts.get(code, "Anomalie détectée par le système de surveillance du véhicule.")


def _generate_car_voice_fallback(code: int, label: str) -> str:
    fallbacks = {
        33: "Batterie à plat ! J'arrive plus à rien, appelle du renfort !",
        37: "Je suis en train de bouillir ! Gare-toi vite, j'ai trop chaud !",
        46: "Mes freins font la grève ! C'est le moment de prier... et de s'arrêter !",
        40: "Mon huile disparaît ! Si tu continues, mon moteur va chanter son dernier air.",
        50: "Pneu à plat ! Je boite comme un cheval fatigué, arrête-toi !",
        36: "Mon cœur lâche ! Le moteur est K.O., appelle le mécanicien !",
    }
    return fallbacks.get(code, f"Hé, on a un souci avec {label.lower()} ! Faut s'en occuper vite.")


def compute_weekly_score(driver_cin: str) -> dict:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        week_ago = datetime.now() - timedelta(days=7)
        cursor.execute("""
            SELECT added_info AS code, COUNT(*) AS cnt FROM events
            WHERE driver_id = %s AND subtype = 11
              AND added_info IS NOT NULL AND added_info != 0 AND date >= %s
            GROUP BY added_info
        """, (driver_cin, week_ago))
        rows = cursor.fetchall()

        categories = {"vitesse": 100, "freinage": 100, "vigilance": 100,
                      "fatigue": 100, "securite": 100}
        events_summary = []

        for row in rows:
            code, cnt = row["code"], row["cnt"]
            if code in SCORE_PENALTIES:
                cat, penalty = SCORE_PENALTIES[code]
                categories[cat] = max(0, categories[cat] + penalty * cnt)
            label, _ = _get_label_description(code)
            events_summary.append(f"{label}: {cnt} fois")

        global_score = round(sum(categories.values()) / len(categories))
        prompt = (f"Score global: {global_score}/100\n"
                  f"Catégories: {json.dumps(categories, ensure_ascii=False)}\n"
                  f"Events: {', '.join(events_summary) or 'Aucun event négatif'}\n"
                  "Génère le rapport conducteur.")
        raw       = _call_llm(SCORING_SYSTEM, prompt, max_tokens=400)
        ai_report = _parse_json_response(raw)

        score_data = {
            "driver_id":    driver_cin,
            "week_start":   week_ago.strftime("%Y-%m-%d"),
            "global_score": global_score,
            "categories":   categories,
            "events_count": len(rows),
            "ai_report":    ai_report,
            "computed_at":  datetime.now().isoformat(),
        }
        _save_driver_score(cursor, conn, driver_cin, score_data)
        return score_data
    finally:
        conn.close()


def _save_driver_score(cursor, conn, driver_cin: str, score_data: dict):
    try:
        cursor.execute("""
            INSERT INTO driver_scores
                (driver_id, week_start, global_score, score_vitesse, score_freinage,
                 score_vigilance, score_fatigue, score_securite, ai_report, computed_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                global_score=VALUES(global_score), score_vitesse=VALUES(score_vitesse),
                score_freinage=VALUES(score_freinage), score_vigilance=VALUES(score_vigilance),
                score_fatigue=VALUES(score_fatigue), score_securite=VALUES(score_securite),
                ai_report=VALUES(ai_report), computed_at=VALUES(computed_at)
        """, (
            driver_cin, score_data["week_start"], score_data["global_score"],
            score_data["categories"]["vitesse"], score_data["categories"]["freinage"],
            score_data["categories"]["vigilance"], score_data["categories"]["fatigue"],
            score_data["categories"]["securite"],
            json.dumps(score_data["ai_report"], ensure_ascii=False),
            score_data["computed_at"],
        ))
        conn.commit()
    except Exception as e:
        print(f">>> Erreur save score: {e}")


def analyze_danger_pattern(recent_events: list, driver_cin: str) -> dict | None:
    codes = {e.get("code") for e in recent_events if e.get("code")}
    danger_patterns = [
        ({12, 22}, "Fatigue + Excès de vitesse"),
        ({12, 11}, "Fatigue + Distraction"),
        ({1,  22}, "Risque collision + Vitesse"),
        ({9,  22}, "Téléphone + Vitesse"),
        ({12, 9},  "Fatigue + Téléphone"),
    ]
    for pattern_codes, pattern_name in danger_patterns:
        if pattern_codes.issubset(codes):
            message = get_combined_pattern_message(pattern_name)
            return {
                "type":        "danger_pattern",
                "pattern":     pattern_name,
                "message":     message,
                "car_voice":   message,
                "severity":    "critical",
                "driver_cin":  driver_cin,
                "detected_at": datetime.now().isoformat(),
                "codes":       list(pattern_codes),
            }
    return None


FALLBACK_VALUES = {
    'Diagnostic en cours de génération par IA...',
    'Analyse en cours',
    'En cours evaluation',
    'Consultez votre mécanicien',
    'Consulter un mécanicien',
    'Analyse des données en cours',
    'Consultez un mécanicien qualifié',
    'Risque inconnu — consultez un professionnel',
    'Risque de dommages si non traité',
}


def _is_real_diagnostic(diag: dict) -> bool:
    for key in ('diagnosis', 'cause', 'action_required'):
        val = (diag.get(key) or '').strip()
        if not val or val in FALLBACK_VALUES:
            return False
    return True


def save_diagnostic(cursor, conn, event_id: int, driver_cin: str, diag: dict):
    try:
        is_real = _is_real_diagnostic(diag)

        if is_real:
            cursor.execute("""
                INSERT INTO ai_diagnostics
                    (event_id, driver_id, code, severity, label, car_voice,
                     diagnosis, cause, action_required, estimated_risk,
                     urgency_hours, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON DUPLICATE KEY UPDATE
                    severity         = VALUES(severity),
                    label            = VALUES(label),
                    car_voice        = VALUES(car_voice),
                    diagnosis        = VALUES(diagnosis),
                    cause            = VALUES(cause),
                    action_required  = VALUES(action_required),
                    estimated_risk   = VALUES(estimated_risk),
                    urgency_hours    = VALUES(urgency_hours)
            """, (
                event_id, driver_cin, diag.get("code"), diag.get("severity"),
                diag.get("label"), diag.get("car_voice"), diag.get("diagnosis"),
                diag.get("cause"), diag.get("action_required"),
                diag.get("estimated_risk"), diag.get("urgency_hours"),
            ))
            conn.commit()
            print(f">>> [SAVE] ✅ Diagnostic COMPLET sauvegardé pour event {event_id}")
        else:
            cursor.execute("""
                INSERT IGNORE INTO ai_diagnostics
                    (event_id, driver_id, code, severity, label, car_voice,
                     diagnosis, cause, action_required, estimated_risk,
                     urgency_hours, created_at)
                VALUES (%s, %s, %s, %s, %s, %s,
                        'Diagnostic en cours de génération par l\'IA...',
                        'Analyse en cours',
                        'Consultez votre mécanicien',
                        'Risque de dommages si non traité',
                        %s, NOW())
            """, (
                event_id, driver_cin, diag.get("code"), diag.get("severity"),
                diag.get("label"), diag.get("car_voice"),
                diag.get("urgency_hours", 24),
            ))
            conn.commit()
    except Exception as e:
        print(f">>> Erreur save diagnostic: {e}")


def process_events_with_ai():
    global _combined_alerts_cache
    print(f">>> [AI-AGENT] Démarrage à {datetime.now()}")
    conn   = get_connection()
    cursor = conn.cursor()

    now = datetime.now()
    to_delete = [k for k, ts in _combined_alerts_cache.items()
                 if (now - ts).total_seconds() > 60]
    for k in to_delete:
        del _combined_alerts_cache[k]

    try:
        cursor.execute("""
            SELECT
                e.id            AS event_id,
                e.date,
                e.added_info    AS code,
                e.driver_id,
                d.fcm_token,
                d.vehicule_id,
                dev.id          AS device_id,
                v.mark,
                v.model,
                v.matricule,
                COALESCE(t.max_speed_kmh,   120) AS max_speed_kmh,
                COALESCE(t.max_engine_temp, 100) AS max_engine_temp,
                COALESCE(t.max_car_temp,     80) AS max_car_temp,
                COALESCE(t.idle_max_minutes,  5) AS idle_max_minutes
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
            LEFT JOIN device dev ON dev.vehicule_id = d.vehicule_id
            LEFT JOIN alert_thresholds t ON t.driver_id = e.driver_id
            WHERE e.subtype = 11
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
              AND (e.is_notified IS FALSE OR e.is_notified IS NULL)
            ORDER BY e.date ASC
            LIMIT 50
        """)
        events = cursor.fetchall()
        print(f">>> [AI-AGENT] {len(events)} events à traiter")
        for ev in events:
            print(f">>> [DEBUG] event_id={ev['event_id']} code={ev['code']} "
                  f"max_speed_kmh={ev['max_speed_kmh']} device_id={ev['device_id']}")

        if not events:
            return

        THRESHOLD_CODES = {22, 29, 37, 40}

        def _check_threshold(ev: dict) -> bool:
            code      = ev["code"]
            if code not in THRESHOLD_CODES:
                return True
            device_id = ev.get("device_id")
            if not device_id:
                return True
            arch_table = f"arch_{device_id}"
            c2 = conn.cursor()

            if code == 22:
                has_custom = ev["max_speed_kmh"] != 120
                print(f">>> [CHECK] has_custom={has_custom} max_speed_kmh={ev['max_speed_kmh']}")
                if not has_custom:
                    return True
                c2.execute(f"""
                    SELECT MAX(speed) AS max_speed FROM {arch_table}
                    WHERE id_device = %s AND date BETWEEN %s AND %s
                """, (device_id, ev["date"] - timedelta(minutes=5), ev["date"]))
                row = c2.fetchone()
                print(f">>> [CHECK] row={row}")
                if not row or row["max_speed"] is None or row["max_speed"] == 0:
                    return True
                real_speed = row["max_speed"]
                print(f">>> [SEUIL] Event {ev['event_id']} vitesse_max={real_speed} seuil={ev['max_speed_kmh']}")
                return real_speed > ev["max_speed_kmh"]

            elif code == 29:
                has_custom = ev["idle_max_minutes"] != 5
                if not has_custom:
                    return True
                c2.execute(f"""
                    SELECT date, speed, ignition FROM {arch_table}
                    WHERE id_device = %s AND date <= %s
                    ORDER BY date DESC LIMIT 50
                """, (device_id, ev["date"]))
                rows = c2.fetchall()
                if not rows:
                    return True
                idle_seconds = 0
                for i in range(len(rows) - 1):
                    curr = rows[i]
                    nxt  = rows[i + 1]
                    if (curr["speed"] or 0) == 0 and (curr["ignition"] or 0) == 1:
                        diff = (curr["date"] - nxt["date"]).total_seconds()
                        idle_seconds += diff
                    else:
                        break
                idle_minutes = idle_seconds / 60
                print(f">>> [SEUIL] Event {ev['event_id']} ralenti={idle_minutes:.1f}min seuil={ev['idle_max_minutes']}")
                return idle_minutes > ev["idle_max_minutes"]

            elif code == 37:
                has_custom = ev["max_engine_temp"] != 100
                if not has_custom:
                    return True
                c2.execute(f"""
                    SELECT temp_engine FROM {arch_table}
                    WHERE id_device = %s AND date <= %s
                    ORDER BY date DESC LIMIT 1
                """, (device_id, ev["date"]))
                row = c2.fetchone()
                if not row or row["temp_engine"] is None or row["temp_engine"] == 0:
                    return True
                real_temp = row["temp_engine"]
                print(f">>> [SEUIL] Event {ev['event_id']} temp_moteur={real_temp} seuil={ev['max_engine_temp']}")
                return real_temp > ev["max_engine_temp"]

            elif code == 40:
                has_custom = ev["max_car_temp"] != 80
                if not has_custom:
                    return True
                c2.execute(f"""
                    SELECT temp FROM {arch_table}
                    WHERE id_device = %s AND date <= %s
                    ORDER BY date DESC LIMIT 1
                """, (device_id, ev["date"]))
                row = c2.fetchone()
                if not row or row["temp"] is None or row["temp"] == 0:
                    return True
                real_temp = row["temp"]
                print(f">>> [SEUIL] Event {ev['event_id']} temp_voiture={real_temp} seuil={ev['max_car_temp']}")
                return real_temp > ev["max_car_temp"]

            return True

        def get_category_from_code(code: int) -> str:
            mapping = {
                # Sécurité routière
                1:  "securite",  # Collision frontale
                2:  "securite",  # Piéton détecté
                3:  "securite",  # Sortie de voie
                30: "securite",  # Collision détectée
                # Téléphone
                9:  "telephone",
                # Fume
                10: "fume",
                # Distraction
                11: "distraction",
                14: "distraction",
                # Fatigue
                12: "fatigue",
                29: "fatigue",
                # Vitesse
                22: "vitesse",
                # Comportement conduite → vitesse
                23: "vitesse",  # Accélération brusque
                24: "vitesse",  # Freinage brusque
                25: "vitesse",  # Virage brusque
                49: "vitesse",  # Arrêt brutal
                # Pannes mécaniques
                32: "panne", 33: "panne", 34: "panne",
                36: "panne", 37: "panne", 38: "panne", 39: "panne",
                40: "panne", 41: "panne", 42: "panne", 43: "panne",
                44: "panne", 45: "panne", 46: "panne", 48: "panne",
                50: "panne", 51: "panne", 52: "panne",
                # Info
                17: "info", 18: "info",
            }
            return mapping.get(code, "panne")

        # 1. Regrouper par conducteur
        driver_events: dict[str, list] = {}
        for ev in events:
            driver_events.setdefault(ev["driver_id"], []).append({"code": ev["code"]})

        # 2. Patterns dangereux
        driver_patterns: dict[str, dict] = {}
        for driver_id, ev_list in driver_events.items():
            pattern = analyze_danger_pattern(ev_list, driver_id)
            if pattern:
                driver_patterns[driver_id] = pattern

        NON_PANNE_CODES = {17, 18}

        # 3. Traiter chaque event
        for ev in events:
            code      = ev["code"]
            driver_id = ev["driver_id"]

            # Vérifier préférences driver
            category = get_category_from_code(code)
            if not is_alert_allowed(driver_id, category):
                print(f">>> [AI-AGENT] Alerte {category} (code {code}) désactivée pour {driver_id}, ignorée")
                cursor.execute(
                    "UPDATE events SET is_notified = TRUE, date = NOW() WHERE id = %s",
                    (ev["event_id"],)
                )
                conn.commit()
                continue

            label, description = get_alert_info(code)
            title         = get_title(code)
            is_critical   = code in CRITICAL_CODES
            vehicule_info = f"{ev['mark'] or '?'} {ev['model'] or ''} ({ev['matricule'] or 'N/A'})"

            diag = None
            if code not in NON_PANNE_CODES:
                try:
                    diag = generate_ai_diagnostic(code, {
                        "mark": ev["mark"],
                        "model": ev["model"],
                        "matricule": ev["matricule"],
                    })
                    save_diagnostic(cursor, conn, ev["event_id"], ev["driver_id"], diag)
                except Exception as e:
                    print(f">>> [AI-AGENT] Erreur diagnostic code {code}: {e}")

            send_normal = True
            if driver_id in driver_patterns:
                if code in set(driver_patterns[driver_id].get("codes", [])):
                    send_normal = False

            if send_normal:
                send_normal = _check_threshold(ev)

            print(f">>> [FCM] token={ev.get('fcm_token')} send_normal={send_normal}")

            if ev.get("fcm_token") and send_normal:
                _send_fcm(
                    token=ev["fcm_token"],
                    title=title,
                    body=f"{vehicule_info} — {description}",
                    data={
                        "event_id":       str(ev["event_id"]),
                        "code":           str(code),
                        "vehicule":       vehicule_info,
                        "date":           str(ev["date"]),
                        "is_critical":    str(is_critical).lower(),
                        "type":           "panne",
                        "car_voice":      description or "",
                        "has_diagnostic": str(diag is not None).lower(),
                        "driver_cin":     str(driver_id),
                    },
                    is_critical=is_critical,
                    code=code,
                )

            cursor.execute(
                "UPDATE events SET is_notified = TRUE, date = NOW() WHERE id = %s",
                (ev["event_id"],)
            )
            conn.commit()
            print(f">>> [AI-AGENT] Event {ev['event_id']} (code {code}) traité")

        # 4. Alertes combinées
        for driver_id, pattern in driver_patterns.items():
            fcm_token = next((ev["fcm_token"] for ev in events
                              if ev["driver_id"] == driver_id), None)
            if fcm_token:
                cache_key = (driver_id, pattern["pattern"])
                if cache_key not in _combined_alerts_cache:
                    if is_alert_allowed(driver_id, "distraction"):
                        _send_fcm(
                            token=fcm_token,
                            title="⚠️ ALERTE COMBINÉE",
                            body=pattern["message"],
                            data={
                                "type":       "danger_pattern",
                                "pattern":    pattern["pattern"],
                                "severity":   "critical",
                                "car_voice":  pattern["message"],
                                "driver_cin": driver_id,
                            },
                            is_critical=True,
                            code=next(iter(pattern.get("codes", [0]))),
                        )
                    _combined_alerts_cache[cache_key] = datetime.now()

    except Exception as e:
        print(f">>> [AI-AGENT] EXCEPTION: {e}")
        conn.rollback()
    finally:
        conn.close()


# ── Daily Report ──────────────────────────────────────────────────────────────

def generate_daily_report(driver_cin: str) -> dict | None:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        today     = date.today()
        yesterday = today - timedelta(days=1)

        cursor.execute("""
            SELECT e.added_info AS code, COUNT(*) AS cnt
            FROM events e
            WHERE e.driver_id = %s
              AND e.subtype = 11
              AND DATE(e.date) = %s
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
            GROUP BY e.added_info
        """, (driver_cin, today))
        today_events = cursor.fetchall()

        categories_today = {"vitesse": 100, "freinage": 100, "vigilance": 100,
                            "fatigue": 100, "securite": 100}
        for row in today_events:
            code = row["code"]
            cnt  = row["cnt"]
            if code in SCORE_PENALTIES:
                cat, penalty = SCORE_PENALTIES[code]
                categories_today[cat] = max(0, categories_today[cat] + penalty * cnt)
        score_today = round(sum(categories_today.values()) / len(categories_today))

        cursor.execute("""
            SELECT global_score FROM driver_scores
            WHERE driver_id = %s AND week_start <= %s
            ORDER BY week_start DESC LIMIT 1
        """, (driver_cin, yesterday))
        row_yesterday    = cursor.fetchone()
        score_yesterday  = row_yesterday["global_score"] if row_yesterday else None

        cursor.execute("""
            SELECT v.mark, v.model
            FROM compte_driver d
            JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE d.cin = %s LIMIT 1
        """, (driver_cin,))
        veh          = cursor.fetchone()
        vehicule_name = f"{veh['mark']} {veh['model']}" if veh else "votre véhicule"

        nb   = len(today_events)
        diff = (score_today - score_yesterday) if score_yesterday else None

        if nb == 0:
            intro = f"Bonne nouvelle conducteur ! {vehicule_name} et toi avez passé une journée impeccable 🎉"
        elif nb <= 2:
            intro = f"Alors {vehicule_name} a quelques petites choses à te raconter sur aujourd'hui..."
        else:
            intro = f"Hum... {vehicule_name} a eu une journée chargée, accroche-toi !"

        if nb == 0:
            alerts_summary = "Aucune alerte aujourd'hui ! Mes capteurs sont au repos, c'est le paradis."
        else:
            codes_str      = ", ".join([f"code {r['code']} ({r['cnt']} fois)" for r in today_events])
            alerts_summary = f"J'ai détecté {nb} alerte(s) aujourd'hui : {codes_str}. Mes circuits ont travaillé dur !"

        if diff is None:
            score_comment = f"Score du jour : {score_today}/100. Premier bilan disponible, continuons comme ça !"
        elif diff > 0:
            score_comment = f"Score {score_today}/100, en hausse de {diff} points vs hier ! Tu carburais bien aujourd'hui 🚀"
        elif diff < 0:
            score_comment = f"Score {score_today}/100, en baisse de {abs(diff)} points vs hier. On a connu meilleure route..."
        else:
            score_comment = f"Score {score_today}/100, stable par rapport à hier. Régulier comme un moteur bien huilé !"

        worst_cat = min(categories_today, key=categories_today.get)
        tips = {
            "vitesse":   "Lève le pied un peu, on n'est pas en Formule 1 !",
            "freinage":  "Anticipe les freinages, mes plaquettes te remercieront.",
            "vigilance": "Garde les yeux sur la route, pas sur le téléphone !",
            "fatigue":   "Une petite pause café s'impose, je te le dis en ami.",
            "securite":  "Boucle ta ceinture et respecte les distances de sécurité.",
        }
        tip = tips.get(worst_cat, "Continue à prendre soin de toi et de moi !")

        if score_today >= 80:
            outro = "À demain pour une nouvelle aventure, champion ! 🏆"
        elif score_today >= 60:
            outro = "Repose-toi bien, demain sera meilleur ! 💪"
        else:
            outro = "On repart de zéro demain, j'y crois pour nous deux ! 🔧"

        report = {
            "intro":           intro,
            "alerts_summary":  alerts_summary,
            "score_comment":   score_comment,
            "tip":             tip,
            "outro":           outro,
            "score_today":     score_today,
            "score_yesterday": score_yesterday,
            "events_count":    nb,
            "events":          [{"code": r["code"], "count": r["cnt"]} for r in today_events],
            "generated_at":    datetime.now().isoformat(),
            "vehicule":        vehicule_name,
            "score_vitesse":   categories_today["vitesse"],
            "score_freinage":  categories_today["freinage"],
            "score_vigilance": categories_today["vigilance"],
            "score_fatigue":   categories_today["fatigue"],
            "score_securite":  categories_today["securite"],
        }

        cursor.execute("""
            INSERT INTO daily_reports (driver_id, report_date, report_json, score_today, created_at)
            VALUES (%s, %s, %s, %s, NOW())
            ON DUPLICATE KEY UPDATE
                report_json = VALUES(report_json),
                score_today = VALUES(score_today),
                created_at  = NOW()
        """, (driver_cin, today, json.dumps(report, ensure_ascii=False), score_today))
        conn.commit()

        return report

    except Exception as e:
        import traceback
        print(f">>> [DAILY-REPORT] ERREUR: {e}")
        traceback.print_exc()
        return None
    finally:
        conn.close()


def send_daily_reports():
    print(f">>> [DAILY-REPORT] Démarrage à {datetime.now()}")
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.cin, d.fcm_token, COALESCE(d.report_hour, 20) AS report_hour
            FROM compte_driver d
            WHERE d.fcm_token IS NOT NULL AND d.fcm_token != ''
        """)
        drivers = cursor.fetchall()
        today   = date.today()

        for drv in drivers:
            cursor.execute("""
                SELECT 1 FROM daily_reports
                WHERE driver_id = %s AND report_date = %s
                LIMIT 1
            """, (drv["cin"], today))
            if cursor.fetchone():
                print(f">>> [DAILY-REPORT] Déjà envoyé aujourd'hui pour {drv['cin']}, skip")
                continue

            report = generate_daily_report(drv["cin"])
            if not report:
                continue

            _send_fcm(
                token=drv["fcm_token"],
                title="🚗 Ton rapport du jour est prêt !",
                body="Viens, j'ai des choses à te raconter sur notre journée...",
                data={
                    "type":        "daily_report",
                    "driver_cin":  str(drv["cin"]),
                    "report_date": str(today),
                    "score_today": str(report.get("score_today", 0)),
                },
                is_critical=False,
                code=0,
            )
            print(f">>> [DAILY-REPORT] ✅ Rapport envoyé pour {drv['cin']}")

    except Exception as e:
        import traceback
        print(f">>> [DAILY-REPORT] ERREUR: {e}")
        traceback.print_exc()
    finally:
        conn.close()
def get_last_pannes(driver_cin: str) -> list:
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        from services.alert_messages import get_panne_position, MECHANICAL_CODES

        if not MECHANICAL_CODES:
            return []

        cursor.execute("""
            SELECT e.id AS event_id, e.added_info AS code, e.date
            FROM events e
            WHERE e.driver_id = %s
              AND e.subtype = 11
              AND e.added_info IN %s
              AND DATE(e.date) = CURDATE()
            ORDER BY e.date DESC
            LIMIT 10
        """, (driver_cin, tuple(MECHANICAL_CODES)))

        rows = cursor.fetchall()
        pannes = []
        seen_positions = set()

        for row in rows:
            code  = row["code"]
            label, description = get_alert_info(code)
            color, category    = get_alert_style(code)
            pos                = get_panne_position(code)
            pos_key            = pos["position_key"]

            if pos_key in seen_positions:
                continue
            seen_positions.add(pos_key)

            pannes.append({
                "event_id":     row["event_id"],
                "code":         code,
                "label":        label,
                "description":  description,
                "color":        color,
                "category":     category,
                "position_key": pos_key,
                "pos_top":      pos["pos_top"],
                "pos_left":     pos["pos_left"],
                "date":         str(row["date"]),
            })

        return pannes
    except Exception as e:
        print(f">>> [LAST-PANNES] ERREUR: {e}")
        return []
    finally:
        conn.close()