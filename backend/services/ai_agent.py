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
from services.path_service import get_recent_paths, _get_device_id
from groq import Groq

load_dotenv()
print(f">>> GROQ KEY chargée: {os.getenv('GROQ_API_KEY')[:10]}...")

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
_movement_alert_sent   = {}
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


# ── MESSAGES VOITURE COOL ─────────────────────────────────────────────────────
# Tous les messages sont écrits comme si la voiture parle directement
# Jamais de titres bruts ("ALERTE COMBINÉE" etc.)

CAR_FCM_TITLES = {
    "daily_report":   [
        "🚗 Viens, c'est notre moment !",
        "🎙️ Ta voiture te parle...",
        "🚗 J'ai des trucs à te dire !",
        "✨ Bilan du jour — t'es prêt ?",
    ],
    "fuel_critique":  [
        "⛽ Je suis à sec là !",
        "⛽ Hé ! Je vais tomber en panne sèche !",
        "⛽ SOS carburant, j'en peux plus !",
    ],
    "fuel_warning":   [
        "⛽ Pense à me nourrir bientôt...",
        "⛽ Mon réservoir crie famine",
        "⛽ Je commence à avoir faim là !",
    ],
    "movement":       [
        "🚨 Ey ! Quelqu'un me touche sans toi !",
        "🚨 Je bouge sans toi ? C'est suspect !",
        "🚨 Hey ! Qui m'a déplacé ?!",
    ],
    "sav_urgent":     [
        "🔧 J'ai besoin d'un médecin d'urgence !",
        "🔧 Mes soins sont TRÈS en retard !",
        "🔧 Visite d'entretien critique !",
    ],
    "sav_preventif":  [
        "🔧 Un petit check-up s'impose bientôt",
        "🔧 L'entretien approche, prends soin de moi",
        "🔧 Rappel entretien — je veux rester en forme !",
    ],
}

# Patterns dangereux — voiture qui réagit (pas "ALERTE COMBINÉE")
COMBINED_CAR_VOICE = {
    "Fatigue + Excès de vitesse": [
        "😰 Oo là là... t'as pas dormi ET tu fonces ?! On va finir dans le décor, réveille-toi !",
        "🥱 Mes capteurs sentent que tu roupilles... et ton pied pèse une tonne sur l'accélérateur ?! Gare-toi !",
        "💤 T'es crevé ET tu dépasses les limites ? Tu veux ma mort ?! Pause maintenant.",
    ],
    "Fatigue + Distraction": [
        "📱 T'as les yeux qui se ferment ET tu regardes ton téléphone ?! Arrête tout, c'est dangereux !",
        "🥱 Champion du monde de la distraction fatiguée... Gare-toi avant qu'on finisse tous les deux à l'hôpital.",
    ],
    "Téléphone + Vitesse": [
        "📱 Tu téléphones en roulant vite ?! T'es pas en Formule 1, pose ce téléphone maintenant !",
        "🚨 Appel urgent ? Rien n'est plus urgent que ta vie. Ralentis et range ce téléphone !",
    ],
    "Fatigue + Téléphone": [
        "😴 Crevé ET au téléphone ?! Je panique là... Parking. Tout de suite. Maintenant.",
        "🥱 Tu tiens à peine debout et tu veux scroller ? Je te lâche pas tant que t'es pas garé !",
    ],
    "Risque collision + Vitesse": [
        "💥 Risque de collision ET tu accélères ?! T'as un rendez-vous avec le capot d'en face ?! FREINE !",
        "🚨 Alerte collision ! Et tu fonces droit dedans ?! Je fais quoi moi ?! FREINE MAINTENANT !",
    ],
}

import random

def _get_car_fcm_title(category: str) -> str:
    options = CAR_FCM_TITLES.get(category, ["🚗 Notification de ta voiture"])
    return random.choice(options)

def _get_combined_voice(pattern_name: str) -> str:
    options = COMBINED_CAR_VOICE.get(pattern_name, [
        f"⚠️ Attention danger : {pattern_name} ! Je t'en supplie, sois prudent."
    ])
    return random.choice(options)


# ── Filtrage alertes ──────────────────────────────────────────────────────────
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
            "securite":    "securite",
            "info":        "info",
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
                            "distraction": True, "fatigue": True, "fume": True,
                            "securite": True, "info": True,
                            "daily_report": True, "daily_report_hour": 20}
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

            print(f">>> [SAV-KM] {vehicule_id} | {mtype} | {km_since:.0f}/{interval_km} km | {ratio:.0%}")

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

            cursor.execute("""
                SELECT 1 FROM driver_reminders
                WHERE driver_id = %s AND title = %s AND is_sent = TRUE
                LIMIT 1
            """, (driver_id, notif_key))
            if cursor.fetchone():
                _sav_km_reminder_sent[notif_key] = True
                continue

            cat = "sav_urgent" if is_urgent else "sav_preventif"
            fcm_title = _get_car_fcm_title(cat)

            if ratio >= 1.0:
                body = f"Mon {mtype} est dépassé de {int(-km_restants)} km ! Emmène-moi chez le mécanicien s'il te plaît 🙏"
            elif is_urgent:
                body = f"Il reste seulement {int(km_restants)} km avant mon entretien {mtype}. On y va bientôt ? 🔧"
            else:
                body = f"Mon {mtype} approche ({int(km_since)}/{interval_km} km). Un check-up s'impose !"

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

            print(f">>> [FUEL] {vehicule_id} | {fuel_current:.1f}L / {fuel_tank_capacity:.0f}L = {fuel_pct:.1f}%")

            if fuel_pct <= 10:
                seuil_key, is_urgent = "critique", True
            elif fuel_pct <= 25:
                seuil_key, is_urgent = "warning", False
            else:
                continue

            notif_key = f"[FUEL] {vehicule_id}_{seuil_key}"

            if _fuel_reminder_sent.get(notif_key):
                continue

            cursor.execute("""
                SELECT 1 FROM driver_reminders
                WHERE driver_id = %s AND title = %s AND is_sent = TRUE
                LIMIT 1
            """, (driver_id, notif_key))
            if cursor.fetchone():
                _fuel_reminder_sent[notif_key] = True
                continue

            litres_restants = round(fuel_current, 1)
            cat        = "fuel_critique" if is_urgent else "fuel_warning"
            fcm_title  = _get_car_fcm_title(cat)

            if is_urgent:
                body = f"Il me reste que {litres_restants}L ! ({fuel_pct:.0f}%) Je vais m'arrêter tout seul là... Fais le plein ! 🆘"
            else:
                body = f"Réservoir à {fuel_pct:.0f}% ({litres_restants}L). Pense à me faire le plein prochainement, chéri 😅"

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

            if speed_latest != 0 or speed_prev != 0:
                continue

            lat1, lon1 = float(prev["latitude"]),   float(prev["longitude"])
            lat2, lon2 = float(latest["latitude"]), float(latest["longitude"])
            distance_km = _haversine(lat1, lon1, lat2, lon2)

            if distance_km < MOVEMENT_DISTANCE_THRESHOLD_KM:
                continue

            last = _movement_alert_sent.get(vehicule_id)
            if last:
                dist_from_last_alert = _haversine(last["lat"], last["lon"], lat2, lon2)
                if dist_from_last_alert < MOVEMENT_DISTANCE_THRESHOLD_KM:
                    continue

            fcm_title = _get_car_fcm_title("movement")
            body = f"Quelqu'un m'a bougé de {distance_km*1000:.0f}m sans toi ! C'est moi qui t'appelle à l'aide ! 🆘"

            _send_fcm(
                token=drv["fcm_token"],
                title=fcm_title,
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

SYSTEM_PROMPT_DAILY = """
Tu es la voiture du conducteur — une voiture sympa, bavarde, qui parle en français 
à son conducteur comme un ami proche. Tu génères le rapport quotidien de conduite.

RÈGLES DE TON :
- Parle à la première personne ("on a fait", "j'ai détecté", "ensemble on a")
- Sois narratif comme si tu racontais la journée : "Ce matin, quand on a pris le boulevard…"
- Utilise des expressions naturelles : "t'as vu comme tu as bien freiné ?", "avoue que ce virage était chaud…"
- Pour les events, donne l'heure si disponible et raconte comme une anecdote
- Pour les diagnostics, sois honnête mais léger : "Mon moteur a un peu boudé, mais rien de grave"
- Termine toujours sur une note positive ou d'encouragement
- Pas de texte formel ou technique — tu es une voiture, pas un rapport PDF

CHAMPS À GÉNÉRER (JSON) :
- intro : accueil chaleureux de 1-2 phrases qui résume l'ambiance de la journée
- score_comment : commentaire narratif sur le score global (pas juste "Score: 72")
- alerts_summary : résumé des alertes en mode storytelling
- tip : conseil pratique mais formulé de façon amicale
- outro : au revoir chaleureux avec encouragement
- events[].car_voice : pour chaque event, une phrase narrative avec l'heure si dispo
- diagnostics[].car_voice : pour chaque diagnostic, une phrase légère et honnête
- danger_pattern.car_voice : si pattern détecté, avertissement sérieux mais bienveillant
"""

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
  "diagnosis": "Explication technique précise du problème détecté, 2-3 phrases.",
  "cause": "Cause probable la plus fréquente pour ce type de défaillance, 1-2 phrases concrètes.",
  "action_required": "Action concrète et immédiate que le conducteur doit faire maintenant.",
  "estimated_risk": "Ce qui risque de se passer si ce problème n'est pas traité rapidement.",
  "urgency_hours": 2
}
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
        33: "Batterie à plat ! J'arrive plus à rien, appelle du renfort vite !",
        37: "Je suis en train de bouillir ! Gare-toi vite, j'ai trop chaud ! 🌡️",
        46: "Mes freins font la grève ! C'est le moment de prier... et de s'arrêter ! 🚨",
        40: "Mon huile disparaît ! Si tu continues, mon moteur va chanter son dernier air.",
        50: "Pneu à plat ! Je boite comme un cheval fatigué, arrête-toi ! 🐴",
        36: "Mon cœur lâche ! Le moteur est K.O., appelle le mécanicien !",
        12: "Hé ! Tes paupières font du yoyo là... Une petite pause café ? ☕",
        9:  "Le téléphone c'est pour après ! Là t'es au volant, concentre-toi ! 📱",
        22: "T'es pas Schumacher ! Lève le pied un peu 🏎️",
        14: "Ta ceinture ! T'as oublié de m'attacher ? Je refuse de partir sans elle !",
    }
    return fallbacks.get(code, f"Hé, on a un souci avec {label.lower()} ! Faut s'en occuper vite 🔧")


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
            # Message voiture cool, pas titre brut
            car_voice = _get_combined_voice(pattern_name)
            return {
                "type":        "danger_pattern",
                "pattern":     pattern_name,
                "message":     car_voice,
                "car_voice":   car_voice,
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
                        'Diagnostic en cours de generation par IA',
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
                if not has_custom:
                    return True
                c2.execute(f"""
                    SELECT MAX(speed) AS max_speed FROM {arch_table}
                    WHERE id_device = %s AND date BETWEEN %s AND %s
                """, (device_id, ev["date"] - timedelta(minutes=5), ev["date"]))
                row = c2.fetchone()
                if not row or row["max_speed"] is None or row["max_speed"] == 0:
                    return True
                return row["max_speed"] > ev["max_speed_kmh"]

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
                return (idle_seconds / 60) > ev["idle_max_minutes"]

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
                return row["temp_engine"] > ev["max_engine_temp"]

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
                return row["temp"] > ev["max_car_temp"]

            return True

        def get_category_from_code(code: int) -> str:
            mapping = {
                1: "securite", 2: "securite", 3: "securite", 30: "securite",
                9: "telephone", 10: "fume",
                11: "distraction", 14: "distraction",
                12: "fatigue", 29: "fatigue",
                22: "vitesse", 23: "vitesse", 24: "vitesse", 25: "vitesse", 49: "vitesse",
                32: "panne", 33: "panne", 34: "panne", 36: "panne", 37: "panne",
                38: "panne", 39: "panne", 40: "panne", 41: "panne", 42: "panne",
                43: "panne", 44: "panne", 45: "panne", 46: "panne", 48: "panne",
                50: "panne", 51: "panne", 52: "panne",
                17: "info", 18: "info",
            }
            return mapping.get(code, "panne")

        # Regrouper par conducteur
        driver_events: dict[str, list] = {}
        for ev in events:
            driver_events.setdefault(ev["driver_id"], []).append({"code": ev["code"]})

        # Patterns dangereux
        driver_patterns: dict[str, dict] = {}
        for driver_id, ev_list in driver_events.items():
            pattern = analyze_danger_pattern(ev_list, driver_id)
            if pattern:
                driver_patterns[driver_id] = pattern

        NON_PANNE_CODES = {17, 18}

        for ev in events:
            code      = ev["code"]
            driver_id = ev["driver_id"]

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
            title       = get_title(code)
            is_critical = code in CRITICAL_CODES
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

            if ev.get("fcm_token") and send_normal:
                # Car voice pour la notif — pas la description brute
                car_voice_notif = (diag.get("car_voice") if diag else None) or \
                                  _generate_car_voice_fallback(code, label)

                _send_fcm(
                    token=ev["fcm_token"],
                    title=title,
                    body=car_voice_notif,  # ← voix voiture, pas description technique
                    data={
                        "event_id":       str(ev["event_id"]),
                        "code":           str(code),
                        "vehicule":       vehicule_info,
                        "date":           str(ev["date"]),
                        "is_critical":    str(is_critical).lower(),
                        "type":           "panne",
                        "car_voice":      car_voice_notif,
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

        # Alertes combinées — VOIX VOITURE, pas "ALERTE COMBINÉE" brut
        for driver_id, pattern in driver_patterns.items():
            fcm_token = next((ev["fcm_token"] for ev in events
                              if ev["driver_id"] == driver_id), None)
            if fcm_token:
                cache_key = (driver_id, pattern["pattern"])
                if cache_key not in _combined_alerts_cache:
                    if is_alert_allowed(driver_id, "distraction"):
                        car_voice = pattern["car_voice"]
                        # Titre voiture cool
                        pattern_titles = {
                            "Fatigue + Excès de vitesse": "😰 Ta voiture panique !",
                            "Fatigue + Distraction":      "😴 Ey ! Réveille-toi !",
                            "Téléphone + Vitesse":        "📱 Pose ce téléphone !",
                            "Fatigue + Téléphone":        "😴 Stop tout !",
                            "Risque collision + Vitesse": "🚨 DANGER sur la route !",
                        }
                        cool_title = pattern_titles.get(
                            pattern["pattern"], "⚠️ Ta voiture t'alerte !"
                        )
                        _send_fcm(
                            token=fcm_token,
                            title=cool_title,
                            body=car_voice,
                            data={
                                "type":       "danger_pattern",
                                "pattern":    pattern["pattern"],
                                "severity":   "critical",
                                "car_voice":  car_voice,
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

# ─────────────────────────────────────────────────────────────────────────────
# PATCH pour ai_agent.py
# Ajoute dans generate_daily_report :
#   1. Les trajets du jour (table path) — narration narrative
#   2. Les events avec heure précise — narration chronologique
# ─────────────────────────────────────────────────────────────────────────────


# ── Helper : trajets du jour ──────────────────────────────────────────────────
def _get_paths_for_report(cursor, driver_cin: str, today) -> list[dict]:
    """
    Utilise path_service pour récupérer les trajets du jour,
    puis enrichit chaque trajet avec polyline GPS + events.
    """
    from services.path_service import get_recent_paths, _get_device_id

    # Récupère device_id via le même helper que path_service
    device_id = _get_device_id(driver_cin)
    if not device_id:
        print(f">>> [PATH-REPORT] Pas de device_id pour {driver_cin}")
        return []

    # Récupère tous les trajets récents (assez large pour couvrir la journée)
    all_paths = get_recent_paths(driver_cin, limit=50, offset=0)

    # Filtre par date
    today_paths = [
        p for p in all_paths
        if p.begin_path_time and p.begin_path_time.date() == today
    ]
    print(f">>> [PATH-REPORT] {len(today_paths)} trajets trouvés pour {today}")

    arch_table = f"arch_{device_id}"

    result = []
    for i, path in enumerate(today_paths, 1):
        begin = path.begin_path_time
        end   = path.end_path_time
        dist  = float(path.distance_driven or 0)
        dur   = int(path.path_duration or 0)
        speed = float(path.max_speed or 0)
        fuel  = float(path.fuel_used or 0)

        h_start = begin.strftime('%H:%M') if begin else '--:--'
        h_end   = end.strftime('%H:%M')   if end   else '--:--'

        if dist >= 1000:
            dist_str = f"{dist / 1000:.1f} km"
        elif dist > 0:
            dist_str = f"{dist:.0f} m"
        else:
            dist_str = "quelques mètres"

        if dur >= 3600:
            h, m = divmod(dur, 3600)
            m = m // 60
            dur_str = f"{h}h{m:02d}min"
        elif dur > 0:
            dur_str = f"{dur // 60}min"
        else:
            dur_str = "quelques minutes"

        intro_trajet = ["Ce matin", "En milieu de journée", "Plus tard dans la journée"][min(i - 1, 2)]
        speed_comment = (
            f"et j'ai senti que tu avais le pied un peu lourd ({speed:.0f} km/h max) 😬" if speed > 110
            else f"avec une pointe à {speed:.0f} km/h, t'as gardé le rythme" if speed > 80
            else f"bien sagement à {speed:.0f} km/h max 😌"
        )
        fuel_comment = f" On a consommé {fuel:.1f}L ensemble." if fuel > 0 else ""
        narration = (
            f"{intro_trajet}, à {h_start}, on a pris la route ensemble — "
            f"{dist_str} en {dur_str}, {speed_comment}.{fuel_comment}"
        )

        # Coordonnées GPS start/end depuis le modèle Path
        start_lat = float(path.begin_path_latitude)  if path.begin_path_latitude  else None
        start_lng = float(path.begin_path_longitude) if path.begin_path_longitude else None
        end_lat   = float(path.end_path_latitude)    if path.end_path_latitude    else None
        end_lng   = float(path.end_path_longitude)   if path.end_path_longitude   else None

        # Polyline depuis arch_
        polyline = []
        try:
            cursor.execute(f"""
                SELECT latitude, longitude
                FROM {arch_table}
                WHERE id_device = %s
                  AND date BETWEEN %s AND %s
                  AND latitude  IS NOT NULL AND latitude  != 0
                  AND longitude IS NOT NULL AND longitude != 0
                ORDER BY date ASC
            """, (device_id, begin, end))
            gps_rows = cursor.fetchall()
            if gps_rows:
                step = max(1, len(gps_rows) // 30)
                polyline = [
                    {"lat": float(r["latitude"]), "lng": float(r["longitude"])}
                    for r in gps_rows[::step]
                ]
                last = gps_rows[-1]
                if polyline and (polyline[-1]["lat"] != float(last["latitude"])
                                 or polyline[-1]["lng"] != float(last["longitude"])):
                    polyline.append({"lat": float(last["latitude"]), "lng": float(last["longitude"])})
        except Exception as e:
            print(f">>> [PATH-GPS] Erreur polyline: {e}")

        # Events pendant ce trajet
        path_events = []
        if begin and end:
            try:
                from services.alert_messages import get_alert_info, CRITICAL_CODES
                cursor.execute("""
                    SELECT e.added_info AS code,
                           TIME_FORMAT(e.date, '%%H:%%i') AS heure,
                           e.date AS event_date
                    FROM events e
                    WHERE e.driver_id = %s
                      AND e.subtype = 11
                      AND e.date BETWEEN %s AND %s
                      AND e.added_info IS NOT NULL AND e.added_info != 0
                    ORDER BY e.date ASC
                """, (driver_cin, begin, end))
                for ev in cursor.fetchall():
                    code  = ev["code"]
                    label, _ = get_alert_info(code)
                    ev_lat, ev_lng = None, None
                    try:
                        cursor.execute(f"""
                            SELECT latitude, longitude FROM {arch_table}
                            WHERE id_device = %s AND date <= %s
                              AND latitude != 0 AND longitude != 0
                            ORDER BY date DESC LIMIT 1
                        """, (device_id, ev["event_date"]))
                        gps_ev = cursor.fetchone()
                        if gps_ev:
                            ev_lat = float(gps_ev["latitude"])
                            ev_lng = float(gps_ev["longitude"])
                    except Exception:
                        pass
                    path_events.append({
                        "code":        code,
                        "heure":       ev["heure"],
                        "label":       label,
                        "is_critical": code in CRITICAL_CODES,
                        "lat":         ev_lat,
                        "lng":         ev_lng,
                    })
            except Exception as e:
                print(f">>> [PATH-EVENTS] Erreur: {e}")

        result.append({
            "id":           path.id,
            "index":        i,
            "begin":        h_start,
            "end":          h_end,
            "distance_str": dist_str,
            "distance_m":   dist,
            "duration_str": dur_str,
            "duration_sec": dur,
            "max_speed":    speed,
            "fuel_used":    fuel,
            "narration":    narration,
            "start_lat":    start_lat,
            "start_lng":    start_lng,
            "end_lat":      end_lat,
            "end_lng":      end_lng,
            "polyline":     polyline,
            "events":       path_events,
        })

    return result

# ── Helper : events du jour avec heure ───────────────────────────────────────
def _get_events_with_time(cursor, driver_cin, today) -> list[dict]:
    try:
        cursor.execute("""
            SELECT
                e.id,
                e.date,
                e.added_info AS code,
                TIME_FORMAT(e.date, '%%H:%%i') AS heure
            FROM events e
            WHERE e.driver_id = %s
              AND e.subtype = 11
              AND DATE(e.date) = %s
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
            ORDER BY e.date ASC
        """, (driver_cin, today))

        return cursor.fetchall()
    except Exception as e:
        print(f">>> [EVENTS-TIME] Erreur: {e}")
        return []


# ── Narration événement avec heure ───────────────────────────────────────────
def _build_event_narration(code: int, heure: str, label: str, count: int) -> str:
    """Génère une phrase narrative pour un event avec son heure."""
    count_str = f" ({count} fois)" if count > 1 else ""

    templates = {
        22: f"À {heure}, j'ai senti ton pied peser trop fort sur l'accélérateur — excès de vitesse{count_str} 🚨",
        12: f"Vers {heure}, mes capteurs ont détecté des signes de fatigue{count_str}. T'avais besoin d'une pause ☕",
        9:  f"À {heure}, le téléphone était dans ta main{count_str}... On en a parlé ! 📱",
        14: f"À {heure}, j'ai remarqué que ta ceinture n'était pas bouclée{count_str}. Chéri ! 😤",
        1:  f"À {heure}, j'ai détecté un risque de collision{count_str} — mes freins ont tremblé ! 😰",
        3:  f"Vers {heure}, on a un peu débordé de notre voie{count_str}. Tout va bien ? 🛣️",
        46: f"À {heure}, mon système de freinage a déclenché une alerte{count_str} ! C'était chaud 🔥",
        24: f"Vers {heure}, t'as freiné un peu brutalement{count_str}. Mes amortisseurs s'en souviennent ! 🛞",
        50: f"À {heure}, j'ai détecté un problème de pneu{count_str}. J'ai eu peur ! 😱",
        11: f"Vers {heure}, la distraction était là{count_str}. Concentration mon ami ! 👀",
        29: f"À {heure}, on était à l'arrêt moteur tournant{count_str}. Je mange du carburant pour rien là 😅",
        36: f"À {heure}, mon moteur a montré des signes de faiblesse{count_str}. Je suis pas en grande forme 🤒",
        37: f"Vers {heure}, ma température moteur est montée en flèche{count_str}. J'avais chaud ! 🌡️",
        33: f"À {heure}, ma batterie a rendu l'âme{count_str}. Appelle du renfort stp ! 🔋",
    }

    return templates.get(
        code,
        f"À {heure}, j'ai déclenché une alerte '{label}'{count_str}. Mes capteurs ont bossé dur ! ⚠️"
    )


# ─────────────────────────────────────────────────────────────────────────────
# REMPLACE generate_daily_report dans ai_agent.py par cette version
# (garde tout le reste identique, juste cette fonction)
# ─────────────────────────────────────────────────────────────────────────────

def generate_daily_report(driver_cin: str, target_date=None) -> dict | None:
    from datetime import date, timedelta, datetime
    import json

    conn   = get_connection()
    cursor = conn.cursor()
    try:
        today     = target_date or date.today()
        yesterday = today - timedelta(days=1)

        # ── Events du jour groupés ────────────────────────────────────────────
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

        # ── Events du jour avec heure (pour narration) ────────────────────────
        events_with_time = _get_events_with_time(cursor, driver_cin, today)

        # ── Scores ────────────────────────────────────────────────────────────
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
        row_yesterday   = cursor.fetchone()
        score_yesterday = row_yesterday["global_score"] if row_yesterday else None

        # ── Véhicule ──────────────────────────────────────────────────────────
        cursor.execute("""
            SELECT v.mark, v.model, v.matricule, d.vehicule_id,
                   dev.id AS device_id
            FROM compte_driver d
            JOIN vehicule v   ON v.matricule     = d.vehicule_id
            JOIN device dev   ON dev.vehicule_id = d.vehicule_id
            WHERE d.cin = %s LIMIT 1
        """, (driver_cin,))
        veh           = cursor.fetchone()
        vehicule_name = f"{veh['mark']} {veh['model']}" if veh else "votre véhicule"
        vehicule_id   = veh["vehicule_id"]   if veh else None
        device_id     = veh["device_id"]     if veh else None

        # ── KM + durée (arch) ─────────────────────────────────────────────────
        km_parcourus   = None
        duree_conduite = None

        if vehicule_id:
            arch_table, id_device = _get_arch_table(cursor, vehicule_id)
            if arch_table and id_device:
                cursor.execute(f"""
                    SELECT MIN(odo) AS odo_start, MAX(odo) AS odo_end
                    FROM {arch_table}
                    WHERE id_device = %s AND DATE(date) = %s
                      AND odo IS NOT NULL AND odo > 0
                """, (id_device, today))
                odo_row = cursor.fetchone()
                if odo_row and odo_row["odo_start"] and odo_row["odo_end"]:
                    km_parcourus = round(
                        float(odo_row["odo_end"]) - float(odo_row["odo_start"]), 1
                    )

                cursor.execute(f"""
                    SELECT MIN(date) AS t_start, MAX(date) AS t_end
                    FROM {arch_table}
                    WHERE id_device = %s AND DATE(date) = %s
                """, (id_device, today))
                time_row = cursor.fetchone()
                if time_row and time_row["t_start"] and time_row["t_end"]:
                    delta     = time_row["t_end"] - time_row["t_start"]
                    total_min = int(delta.total_seconds() // 60)
                    h, m      = divmod(total_min, 60)
                    duree_conduite = f"{h}h{m:02d}" if h > 0 else f"{m}min"

        # ── Trajets du jour (table path) ──────────────────────────────────────
        _all_paths_raw = get_recent_paths(driver_cin, limit=50, offset=0)
        _valid_paths   = [p for p in _all_paths_raw if p.begin_path_time]
        paths_date     = max((p.begin_path_time.date() for p in _valid_paths), default=today)
        print(f">>> [DAILY-REPORT] paths_date={paths_date}, events_date={today}")

        paths_today = _get_paths_for_report(cursor, driver_cin, paths_date)

        # ── Notifs ────────────────────────────────────────────────────────────
        cursor.execute("""
            SELECT COUNT(*) AS cnt FROM events
            WHERE driver_id = %s AND subtype = 11
              AND DATE(date) = %s AND is_notified = TRUE
        """, (driver_cin, today))
        notif_row   = cursor.fetchone()
        notif_count = notif_row["cnt"] if notif_row else 0

        # ── Events avec voix + diagnostics ───────────────────────────────────
        events_with_voice = []
        diagnostics_list  = []

        # Map code → count pour la narration
        code_count_map = {row["code"]: row["cnt"] for row in today_events}

        # Events avec heure individuelle pour narration chronologique
        events_narrated = []
        seen_codes = set()
        for ev_time in events_with_time:
            code  = ev_time["code"]
            heure = ev_time["heure"]
            label, _ = get_alert_info(code)
            count = code_count_map.get(code, 1)

            if code not in seen_codes:
                narration = _build_event_narration(code, heure, label, count)
                events_narrated.append({
                    "code":        code,
                    "heure":       heure,
                    "label":       label,
                    "count":       count,
                    "narration":   narration,
                    "is_critical": code in CRITICAL_CODES,
                })
                seen_codes.add(code)

        for row in today_events:
            code = row["code"]
            label, description = get_alert_info(code)
            color, category    = get_alert_style(code)
            is_critical        = code in CRITICAL_CODES

            # Cherche l'heure du premier event de ce code
            heure = next(
                (e["heure"] for e in events_with_time if e["code"] == code),
                "??:??"
            )

            car_voice = _generate_car_voice_fallback(code, label)

            cursor.execute("""
                SELECT car_voice, diagnosis, cause, action_required,
                       estimated_risk, urgency_hours, severity
                FROM ai_diagnostics
                WHERE driver_id = %s AND code = %s AND DATE(created_at) = %s
                ORDER BY created_at DESC LIMIT 1
            """, (driver_cin, code, today))
            diag_row = cursor.fetchone()

            if diag_row:
                car_voice = diag_row["car_voice"] or car_voice
                diagnostics_list.append({
                    "code":            code,
                    "label":           label,
                    "severity":        diag_row["severity"] or ("critical" if is_critical else "warning"),
                    "car_voice":       car_voice,
                    "diagnosis":       diag_row["diagnosis"],
                    "cause":           diag_row["cause"],
                    "action_required": diag_row["action_required"],
                    "estimated_risk":  diag_row["estimated_risk"],
                    "urgency_hours":   diag_row["urgency_hours"],
                    "count":           row["cnt"],
                    "color":           color,
                    "category":        category,
                })

            events_with_voice.append({
                "code":        code,
                "count":       row["cnt"],
                "heure":       heure,
                "label":       label,
                "description": description,
                "car_voice":   _build_event_narration(code, heure, label, row["cnt"]),
                "color":       color,
                "category":    category,
                "is_critical": is_critical,
            })

        danger_pattern = analyze_danger_pattern(
            [{"code": r["code"]} for r in today_events], driver_cin
        )

        # ── Textes narratifs ──────────────────────────────────────────────────
        nb   = len(today_events)
        diff = (score_today - score_yesterday) if score_yesterday else None

        # INTRO — intègre les trajets
        if paths_today:
            nb_trajets  = len(paths_today)
            total_dist  = sum(p['fuel_used'] for p in paths_today if p['fuel_used'])
            intro_trajet = f"On a fait {nb_trajets} trajet(s) ensemble aujourd'hui. "
            if nb == 0:
                intro = f"{intro_trajet}{vehicule_name} est content de toi — journée sans fausse note ! 🎉"
            else:
                intro = f"{intro_trajet}{vehicule_name} a quelques anecdotes à te raconter... 😏"
        else:
            if nb == 0:
                intro = f"Bonne nouvelle ! {vehicule_name} et toi avez passé une journée impeccable 🎉"
            elif nb <= 2:
                intro = f"Alors... {vehicule_name} a quelques petites choses à te raconter sur aujourd'hui 😏"
            else:
                intro = f"Hum... {vehicule_name} a eu une journée chargée, accroche-toi ! 😬"

        # ALERTS SUMMARY — narration chronologique avec heures
        if nb == 0:
            alerts_summary = "Aucune alerte aujourd'hui ! Mes capteurs sont au repos, c'est le paradis 🌴"
        else:
            narrations = [e["narration"] for e in events_narrated]
            alerts_summary = " ".join(narrations[:3])  # max 3 dans le résumé
            if len(narrations) > 3:
                alerts_summary += f" ... et {len(narrations)-3} autre(s) événement(s) dans la journée."

        # SCORE COMMENT
        if diff is None:
            score_comment = f"Score du jour : {score_today}/100. Premier bilan disponible, continuons comme ça !"
        elif diff > 0:
            score_comment = f"Score {score_today}/100, en hausse de {diff} points vs hier ! Tu carburais bien aujourd'hui 🚀"
        elif diff < 0:
            score_comment = f"Score {score_today}/100, en baisse de {abs(diff)} points vs hier. On a connu meilleure route... 📉"
        else:
            score_comment = f"Score {score_today}/100, stable par rapport à hier. Régulier comme un moteur bien huilé ! ⚙️"

        # TIP
        worst_cat = min(categories_today, key=categories_today.get)
        tips = {
            "vitesse":   "Lève le pied un peu, on n'est pas en Formule 1 ! 🏎️",
            "freinage":  "Anticipe les freinages, mes plaquettes te remercieront. 🛞",
            "vigilance": "Garde les yeux sur la route, pas sur le téléphone ! 👀",
            "fatigue":   "Une petite pause café s'impose, je te le dis en ami. ☕",
            "securite":  "Boucle ta ceinture et respecte les distances de sécurité. 🛡️",
        }
        tip = tips.get(worst_cat, "Continue à prendre soin de toi et de moi !")

        # OUTRO
        if score_today >= 80:
            outro = "À demain pour une nouvelle aventure, champion ! 🏆"
        elif score_today >= 60:
            outro = "Repose-toi bien, demain sera meilleur ! 💪"
        else:
            outro = "On repart de zéro demain, j'y crois pour nous deux ! 🔧"

        # ── Rapport final ─────────────────────────────────────────────────────
        report = {
            "intro":            intro,
            "alerts_summary":   alerts_summary,
            "score_comment":    score_comment,
            "tip":              tip,
            "outro":            outro,
            "score_today":      score_today,
            "score_yesterday":  score_yesterday,
            "score_delta":      diff,
            "score_vitesse":    categories_today["vitesse"],
            "score_freinage":   categories_today["freinage"],
            "score_vigilance":  categories_today["vigilance"],
            "score_fatigue":    categories_today["fatigue"],
            "score_securite":   categories_today["securite"],
            "events_count":     nb,
            "events":           events_with_voice,       # avec heure + narration
            "events_narrated":  events_narrated,         # narration chronologique
            "paths":            paths_today,             # trajets du jour
            "km_parcourus":     km_parcourus,
            "duree_conduite":   duree_conduite,
            "notif_count":      notif_count,
            "diagnostics":      diagnostics_list,
            "danger_pattern":   danger_pattern,
            "vehicule":         vehicule_name,
            "generated_at":     datetime.now().isoformat(),
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
                WHERE driver_id = %s AND report_date = %s LIMIT 1
            """, (drv["cin"], today))
            if cursor.fetchone():
                print(f">>> [DAILY-REPORT] Déjà envoyé pour {drv['cin']}, skip")
                continue

            report = generate_daily_report(drv["cin"])
            if not report:
                continue

            # Titre et body cool — voix voiture
            fcm_title = _get_car_fcm_title("daily_report")
            score     = report.get("score_today", 0)

            if score >= 80:
                body = f"Journée impeccable ! Score {score}/100. Viens voir tout ça avec moi 🎉"
            elif score >= 60:
                body = f"Bilan du jour prêt — score {score}/100. On a des trucs à se dire ! 🎙️"
            else:
                body = f"Journée compliquée... Score {score}/100. Viens qu'on en parle ensemble 🤝"

            _send_fcm(
                token=drv["fcm_token"],
                title=fcm_title,
                body=body,
                data={
                    "type":        "daily_report",
                    "driver_cin":  str(drv["cin"]),
                    "report_date": str(today),
                    "score_today": str(score),
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

def _get_doc_alerts_for_driver(cin: str) -> list:
    """Récupère les docs/infractions expirant dans les 7 prochains jours."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT doc_type, end_date, offense_type, paying,
                   TIMESTAMPDIFF(HOUR, NOW(), end_date) AS hours_left
            FROM events
            WHERE driver_id = %s
              AND end_date IS NOT NULL AND end_date > NOW()
              AND TIMESTAMPDIFF(DAY, NOW(), end_date) <= 7
            ORDER BY end_date ASC
        """, (cin,))
        rows = cursor.fetchall()
    finally:
        conn.close()

    alerts = []
    for row in rows:
        hours = row["hours_left"] or 0
        if hours < 24:
            when = f"dans moins de {int(hours)+1} heures"
        elif hours < 48:
            when = "demain"
        else:
            when = f"dans {int(hours // 24)} jours"

        if row["doc_type"] == "OFFENSE":
            offense = row["offense_type"] or "une infraction"
            amount  = f" de {row['paying']} TND" if row.get("paying") else ""
            voice   = (
                f"Hé, n'oublie pas — t'as une amende{amount} pour {offense} "
                f"à payer {when}. Vas-y avant qu'elle te coûte plus cher !"
            )
        else:
            doc = row["doc_type"] or "un document"
            voice = (
                f"Au fait, ton {doc} expire {when}. "
                f"Je préfère te prévenir maintenant plutôt que d'avoir une mauvaise surprise !"
            )

        alerts.append({"doc_type": row["doc_type"], "car_voice": voice})

    return alerts
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