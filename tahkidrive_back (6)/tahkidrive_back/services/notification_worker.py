# services/notification_worker.py
from db import get_connection
import firebase_admin
from firebase_admin import credentials, messaging
import os
from datetime import datetime

# ── Init Firebase (une seule fois)
if not firebase_admin._apps:
    cred = credentials.Certificate("firebase_credentials.json")
    firebase_admin.initialize_app(cred)

# ── Dict des codes pannes
PANNE_LABELS = {
    1:  ("Collision frontale", "Risque de collision détecté ! Réduisez la vitesse."),
    2:  ("Piéton détecté", "Un piéton détecté devant le véhicule."),
    3:  ("Sortie de voie", "Le véhicule sort de sa voie !"),
    4:  ("Bumper virtuel", "Approche d'une zone de sécurité virtuelle."),
    9:  ("Téléphone au volant", "Le conducteur utilise son téléphone !"),
    10: ("Cigarette détectée", "Le conducteur fume au volant."),
    11: ("Distraction", "Le conducteur est distrait !"),
    12: ("Fatigue détectée", "Signes de fatigue détectés. Arrêt recommandé !"),
    14: ("Ceinture non bouclée", "Le conducteur ne porte pas sa ceinture !"),
    17: ("Démarrage véhicule", "Le véhicule vient de démarrer."),
    18: ("Arrêt véhicule", "Le véhicule vient de s'arrêter."),
    19: ("Position GPS mise à jour", "Nouvelle position GPS reçue."),
    22: ("Excès de vitesse", "Le véhicule dépasse la vitesse autorisée !"),
    23: ("Accélération brusque", "Accélération brusque détectée."),
    24: ("Freinage brusque", "Freinage brusque détecté."),
    25: ("Virage brusque", "Virage brusque détecté."),
    29: ("Ralenti prolongé", "Le véhicule est au ralenti depuis trop longtemps."),
    30: ("Collision détectée", "Une collision a été détectée !"),
    31: ("Altération du boîtier", "Mouvement suspect du boîtier GPS détecté !"),
    32: ("Batterie faible", "Batterie du véhicule faible."),
    33: ("Batterie déchargée", "Batterie du véhicule déchargée !"),
    34: ("Défaillance alternateur", "L'alternateur ne fonctionne plus correctement."),
    35: ("Défaut système électrique", "Défaut détecté dans le système électrique."),
    36: ("Défaillance moteur", "Défaillance moteur détectée !"),
    37: ("Surchauffe moteur", "Le moteur est en surchauffe !"),
    38: ("Raté d'allumage", "Raté d'allumage moteur détecté."),
    39: ("Moteur calé", "Le moteur s'est calé !"),
    40: ("Pression huile faible", "Pression d'huile trop basse !"),
    41: ("Fuite d'huile", "Fuite d'huile détectée !"),
    42: ("Niveau huile critique", "Niveau d'huile critique !"),
    43: ("Défaillance transmission", "Défaillance de la transmission détectée."),
    44: ("Glissement embrayage", "Glissement de l'embrayage détecté."),
    45: ("Erreur changement vitesse", "Erreur lors du changement de vitesse."),
    46: ("Défaillance freins", "Défaillance du système de freinage !"),
    47: ("Défaut ABS", "Défaut du système ABS détecté !"),
    48: ("Usure freins élevée", "Usure élevée des plaquettes de frein."),
    49: ("Arrêt brutal", "Arrêt brutal du véhicule détecté."),
    50: ("Crevaison détectée", "Crevaison détectée sur un pneu !"),
    51: ("Carburant faible", "Niveau de carburant bas."),
    52: ("Surchauffe générale", "Surchauffe générale du véhicule détectée !"),
}

CRITICAL_CODES = {1, 2, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50}

def process_new_events():
    """Lit les nouveaux events non notifiés (avec added_info non NULL) et envoie les notifications FCM"""
    print(f">>> [DEBUG] Worker exécuté à {datetime.now()}")
    
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # Ne prendre que les events avec added_info NOT NULL (les pannes)
        cursor.execute("""
            SELECT 
                e.id as event_id,
                e.date,
                e.added_info as code,
                e.driver_id,
                d.fcm_token,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN driver d ON d.user_id = e.driver_id
            LEFT JOIN driver_vehicule dv ON dv.driver_id = e.driver_id
            LEFT JOIN vehicule v ON v.id = dv.vehicule_id
            WHERE e.type = 1
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
              AND (e.is_notified IS FALSE OR e.is_notified IS NULL)
            ORDER BY e.date ASC
            LIMIT 50
        """)
        events = cursor.fetchall()
        
        print(f">>> [DEBUG] {len(events)} events (pannes) trouvés")

        if not events:
            return

        for ev in events:
            code = ev['code']
            
            if code not in PANNE_LABELS:
                print(f">>> Code {code} non reconnu, marqué comme notifié")
                cursor.execute("UPDATE events SET is_notified = TRUE WHERE id = %s", (ev['event_id'],))
                conn.commit()
                continue

            title, description = PANNE_LABELS[code]
            vehicule_info = f"{ev['mark'] or '?'} {ev['model'] or ''} ({ev['matricule'] or 'N/A'})"
            message = f"{vehicule_info} — {description}"
            is_critical = code in CRITICAL_CODES

            if ev.get('fcm_token'):
                _send_fcm(
                    token=ev['fcm_token'],
                    title=title,
                    body=message,
                    data={
                        "event_id": str(ev['event_id']),
                        "code": str(code),
                        "vehicule": vehicule_info,
                        "date": str(ev['date']),
                        "is_critical": str(is_critical).lower(),
                        "type": "panne"
                    },
                    is_critical=is_critical,
                )
                print(f">>> Notification envoyée pour event {ev['event_id']} (code {code})")
            else:
                print(f">>> Pas de FCM token pour driver {ev['driver_id']}")

            cursor.execute("UPDATE events SET is_notified = TRUE WHERE id = %s", (ev['event_id'],))
            conn.commit()

    except Exception as e:
        print(f">>> EXCEPTION notification_worker: {e}")
        conn.rollback()
    finally:
        conn.close()

def _send_fcm(token: str, title: str, body: str, data: dict, is_critical: bool):
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(
                priority="high" if is_critical else "normal",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="high" if is_critical else "default",
                    channel_id="alerts_channel",
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
        print(f">>> FCM envoyé: {response}")
    except Exception as e:
        print(f">>> Erreur FCM: {e}")