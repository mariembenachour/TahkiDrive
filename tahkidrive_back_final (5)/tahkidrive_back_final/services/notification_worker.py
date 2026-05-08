# services/notification_worker.py
import firebase_admin
from firebase_admin import credentials, messaging
from datetime import datetime
from db import get_connection
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
                d.fcm_token,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            LEFT JOIN vehicule v ON v.matricule = d.vehicule_id
            WHERE e.subtype = 11
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
              AND (e.is_notified IS FALSE OR e.is_notified IS NULL)
            ORDER BY e.date ASC
            LIMIT 50
        """)
        events = cursor.fetchall()
        print(f">>> [DEBUG] {len(events)} events trouvés")

        if not events:
            return

        for ev in events:
            code = ev["code"]
            title, description = get_alert_info(code)

            if title == "Alerte inconnue":
                cursor.execute(
                    "UPDATE events SET is_notified = TRUE WHERE id = %s",
                    (ev["event_id"],)
                )
                conn.commit()
                continue

            vehicule_info = (
                f"{ev['mark'] or '?'} {ev['model'] or ''} "
                f"({ev['matricule'] or 'N/A'})"
            )
            body        = f"{vehicule_info} — {description}"
            is_critical = code in CRITICAL_CODES

            if ev.get("fcm_token"):
                _send_fcm(
                    token=ev["fcm_token"],
                    title=title,
                    body=body,
                    data={
                        "event_id":    str(ev["event_id"]),
                        "code":        str(code),
                        "vehicule":    vehicule_info,
                        "date":        str(ev["date"]),
                        "is_critical": str(is_critical).lower(),
                        "type":        "panne",
                    },
                    is_critical=is_critical,
                    code=code,
                )
                print(f">>> Notification envoyée event {ev['event_id']} (code {code})")
            else:
                print(f">>> Pas de FCM token pour driver {ev['driver_id']}")

            cursor.execute(
                "UPDATE events SET is_notified = TRUE WHERE id = %s",
                (ev["event_id"],)
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
            priority   = "normal"
        else:
            color, category = get_alert_style(code)
            channel_id = f"alerts_{category}"
            priority   = "high" if is_critical else "normal"

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(
                priority="high" if (is_critical and not is_reminder) else "normal",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="high" if (is_critical and not is_reminder) else "default",
                    channel_id=channel_id,
                    color=color,
                    icon="ic_launcher_notif",
                    tag=category,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
            token=token,
        )
        response = messaging.send(message)
        print(f">>> FCM envoyé [{color} / {category}]: {response}")
    except Exception as e:
        print(f">>> Erreur FCM: {e}")