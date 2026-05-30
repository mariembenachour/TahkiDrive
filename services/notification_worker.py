# services/notification_worker.py

import firebase_admin
from firebase_admin import credentials, messaging
from datetime import datetime
from db import get_connection
from models.event import Event
from models.compte_driver import CompteDriver
from models.vehicule import Vehicule

from services.alert_messages import get_alert_info, get_alert_style, CRITICAL_CODES

if not firebase_admin._apps:
    cred = credentials.Certificate("firebase_credentials.json")
    firebase_admin.initialize_app(cred)


def process_new_events():
    print(f">>> [DEBUG] Worker exécuté à {datetime.now()}")
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                e.id          AS event_id,
                e.date,
                e.added_info  AS code,
                e.driver_id,
                e.subtype,
                e.doc_type,
                e.end_date,
                e.is_notified,
                e.paying,
                e.offense_type,
                e.offense_date,
                d.fcm_token,
                d.cin,
                d.email,
                d.password,
                d.vehicule_id,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE e.subtype = 11
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
              AND e.added_info != 51 
              AND (e.is_notified IS FALSE OR e.is_notified IS NULL)
            ORDER BY e.date ASC
            LIMIT 50
        """)
        rows = cursor.fetchall()
        print(f">>> [DEBUG] {len(rows)} events trouvés")

        if not rows:
            return

        for row in rows:
            ev = Event(
                id           = row["event_id"],
                date         = row["date"],
                subtype      = row["subtype"],
                added_info   = row.get("code"),
                driver_id    = row.get("driver_id"),
                doc_type     = row.get("doc_type"),
                end_date     = row.get("end_date"),
                is_notified  = bool(row.get("is_notified")),
                paying       = row.get("paying"),
                offense_type = row.get("offense_type"),
                offense_date = row.get("offense_date"),
            )
            driver = CompteDriver(
                cin         = row["cin"],
                email       = row["email"],
                password    = row["password"],
                vehicule_id = row.get("vehicule_id"),
            )

            code  = ev.added_info
            title, description = get_alert_info(code)

            if title == "Alerte inconnue":
                cursor.execute(
                    "UPDATE events SET is_notified = TRUE WHERE id = %s", (ev.id,)
                )
                conn.commit()
                continue

            mark      = row.get("mark") or "?"
            model     = row.get("model") or ""
            matricule = row.get("matricule") or "N/A"
            vehicule_info = f"{mark} {model} ({matricule})"

            body        = f"{vehicule_info} — {description}"
            is_critical = code in CRITICAL_CODES

            fcm_token   = row.get("fcm_token")
            driver_cin  = row.get("cin")

            if fcm_token:
                # ✅ Vérifier que ce token appartient bien uniquement à ce driver
                cursor.execute(
                    "SELECT COUNT(*) AS cnt FROM compte_driver WHERE fcm_token = %s AND cin != %s",
                    (fcm_token, driver_cin)
                )
                conflict = cursor.fetchone()
                if conflict and conflict["cnt"] > 0:
                    print(f">>> ⚠️ FCM token partagé pour driver {driver_cin} — nettoyage et notif ignorée")
                    # Nettoyer le token des autres comptes
                    cursor.execute(
                        "UPDATE compte_driver SET fcm_token = NULL WHERE fcm_token = %s AND cin != %s",
                        (fcm_token, driver_cin)
                    )
                    cursor.execute(
                        "UPDATE events SET is_notified = TRUE WHERE id = %s", (ev.id,)
                    )
                    conn.commit()
                    continue

                _send_fcm(
                    token       = fcm_token,
                    title       = title,
                    body        = body,
                    data        = {
                        "event_id":    str(ev.id),
                        "code":        str(code),
                        "vehicule":    vehicule_info,
                        "date":        str(ev.date),
                        "is_critical": str(is_critical).lower(),
                        "type":        "panne",
                    },
                    is_critical = is_critical,
                    code        = code,
                )
                print(f">>> Notification envoyée event {ev.id} (code {code}) → driver {driver_cin}")
            else:
                print(f">>> Pas de FCM token pour driver {driver.cin}")

            cursor.execute(
                "UPDATE events SET is_notified = TRUE WHERE id = %s", (ev.id,)
            )
            conn.commit()

    except Exception as e:
        print(f">>> EXCEPTION notification_worker: {e}")
        conn.rollback()
    finally:
        conn.close()


def _send_fcm(token: str, title: str, body: str, data: dict, is_critical: bool, code: int = 0):
    try:
        notif_type  = data.get("type", "panne")
        is_reminder = notif_type == "reminder"

        if is_reminder:
            channel_id = "reminders_channel"
            color      = "#4CAF50"
            category   = "reminder"
        else:
            color, category = get_alert_style(code)
            channel_id = "alerts_channel"

        message = messaging.Message(
            notification = messaging.Notification(title=title, body=body),
            data         = data,
            android      = messaging.AndroidConfig(
                priority     = "high" if (is_critical and not is_reminder) else "normal",
                notification = messaging.AndroidNotification(
                    sound      = "default",
                    priority   = "high" if (is_critical and not is_reminder) else "default",
                    channel_id = channel_id,
                    color      = color,
                    icon       = "ic_launcher_notif",
                    tag        = category,
                ),
            ),
            apns = messaging.APNSConfig(
                payload = messaging.APNSPayload(
                    aps = messaging.Aps(sound="default"),
                ),
            ),
            token = token,
        )
        response = messaging.send(message)
        print(f">>> FCM envoyé [{color} / {category}]: {response}")
    except Exception as e:
        print(f">>> Erreur FCM: {e}")