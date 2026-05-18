import json
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from db import get_connection
from services.notification_worker import _send_fcm
from services.ai_agent import (
    compute_weekly_score,
    process_events_with_ai,
    check_sav_km_reminders,
    check_fuel_reminders,
    check_vehicle_movement,
    send_daily_reports,
    get_notif_preferences,
    generate_daily_report
)

scheduler = BackgroundScheduler(timezone="Africa/Tunis")

_offense_reminder_sent = {}
_doc_reminder_sent = {}
_daily_report_sent_today = None

# ✅ Change ici pour switcher entre les modes
TEST_MODE = True  # False = mode réel

# ── MODE TEST (secondes) ──────────────────────────────────────────────────────
THRESHOLDS_TEST = [
    (30,  "dans 30 minutes", "30s"),
    (60,  "dans une heure ",    "1m"),
    (120, "dans 24H ",   "2m"),
    (300, "dans une semaine",   "5m"),
]

# ── MODE RÉEL (jours/heures) ──────────────────────────────────────────────────
THRESHOLDS_REAL = [
    (1800,          "dans 30 minutes", "30m"),
    (3600,          "dans 1 heure",    "1h"),
    (12 * 3600,     "dans 12 heures",  "12h"),
    (24 * 3600,     "dans 24 heures",  "24h"),
    (3 * 24 * 3600, "dans 3 jours",    "3d"),
    (7 * 24 * 3600, "dans 1 semaine",  "7d"),
    (14 * 24 * 3600,  "dans 2 semaines", "14d"),
]

# ── Labels pour les seuils du deuxième code ───────────────────────────────────
SECONDS_TO_LABEL = {
    1800:    ("dans 30 minutes", "30m"),
    3600:    ("dans 1 heure",    "1h"),
    43200:   ("dans 12 heures",  "12h"),
    86400:   ("dans 24 heures",  "24h"),
    259200:  ("dans 3 jours",    "3d"),
    604800:  ("dans 1 semaine",  "7d"),
    1209600: ("dans 2 semaines", "14d"),
}

DEFAULT_THRESHOLDS = [1800, 3600, 43200, 86400, 259200, 604800, 1209600]

THRESHOLDS = THRESHOLDS_TEST if TEST_MODE else THRESHOLDS_REAL

# ── Fonctions utilitaires ─────────────────────────────────────────────────────

def _format_seconds(s: int) -> str:
    if s < 3600:
        return f"dans {s // 60} minute(s)"
    elif s < 86400:
        return f"dans {s // 3600} heure(s)"
    elif s < 604800:
        return f"dans {s // 86400} jour(s)"
    else:
        return f"dans {s // 604800} semaine(s)"

def _build_thresholds_for_driver(driver_seconds: list) -> list:
    """
    Retourne [(real_sec, label, key), ...] — toujours en secondes RÉELLES.
    TEST_MODE n'affecte que la fréquence du scheduler, pas les seuils.
    """
    result = []
    for s in driver_seconds:
        label, key = SECONDS_TO_LABEL.get(s, (_format_seconds(s), str(s)))
        result.append((s, label, key))
    return sorted(result, key=lambda x: x[0])

def _find_threshold(seconds_left, thresholds=None):
    """Retourne le threshold le plus petit qui correspond à seconds_left."""
    if thresholds is None:
        thresholds = THRESHOLDS
    for threshold_sec, label, key in thresholds:
        if seconds_left <= threshold_sec:
            return threshold_sec, label, key
    return None

# ── Jobs ──────────────────────────────────────────────────────────────────────

def job_process_events():
    try:
        process_events_with_ai()
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur process_events: {e}")

def job_check_fuel_reminders():
    try:
        check_fuel_reminders()
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur fuel_reminders: {e}")

def job_check_sav_km_reminders():
    try:
        check_sav_km_reminders()
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur sav_km_reminders: {e}")

def job_check_vehicle_movement():
    try:
        check_vehicle_movement()
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur movement: {e}")

def job_daily_report():
    global _daily_report_sent_today
    try:
        today = datetime.now().date()
        if not TEST_MODE and _daily_report_sent_today == today:  # ← seulement en mode réel
          return

        conn   = get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT d.cin, d.fcm_token
                FROM compte_driver d
                WHERE d.fcm_token IS NOT NULL AND d.fcm_token != ''
            """)
            drivers = cursor.fetchall()
        finally:
            conn.close()

        current_hour = datetime.now().hour

        for drv in drivers:
            # Vérifier préférences
            prefs       = get_notif_preferences(drv["cin"])
            notif_prefs = prefs.get("notif_preferences", {})

            # Si daily_report désactivé → skip
            if not notif_prefs.get("daily_report", True):
                print(f">>> [DAILY-REPORT] Désactivé pour {drv['cin']}, skip")
                continue

            # Heure choisie par le driver (défaut 20h)
            report_hour = int(notif_prefs.get("daily_report_hour", 20))

            # En mode test on ignore l'heure, en mode réel on vérifie
            if not TEST_MODE and current_hour != report_hour:
                continue

            # Vérifier si déjà envoyé aujourd'hui
            conn2   = get_connection()
            cursor2 = conn2.cursor()
            try:
                cursor2.execute("""
                    SELECT 1 FROM daily_reports
                    WHERE driver_id = %s AND report_date = %s LIMIT 1
                """, (drv["cin"], today))
                if cursor2.fetchone():
                    continue
            finally:
                conn2.close()

            report = generate_daily_report(drv["cin"])
            if not report:
                continue

            from services.notification_worker import _send_fcm
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
            print(f">>> [DAILY-REPORT] ✅ Rapport envoyé pour {drv['cin']} à {report_hour}h")

        _daily_report_sent_today = today

    except Exception as e:
        import traceback
        print(f">>> [SCHEDULER] Erreur daily_report: {e}")
        traceback.print_exc()
def job_send_reminders():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT r.*, d.fcm_token
            FROM driver_reminders r
            JOIN compte_driver d ON d.cin = r.driver_id
            WHERE r.remind_at <= NOW()
              AND r.is_sent = FALSE
              AND d.fcm_token IS NOT NULL
        """)
        reminders = cursor.fetchall()

        for rem in reminders:
            _send_fcm(
                token=rem["fcm_token"],
                title=rem["title"],
                body=rem["description"] or "",
                data={"type": "reminder", "reminder_id": str(rem["id"])},
                is_critical=False,
            )
            print(f">>> [SCHEDULER] Rappel {rem['id']} envoyé → driver {rem['driver_id']}")

            if rem.get("repeat_days"):
                next_remind = rem["remind_at"] + timedelta(days=rem["repeat_days"])
                cursor.execute(
                    "UPDATE driver_reminders SET remind_at = %s, is_sent = FALSE WHERE id = %s",
                    (next_remind, rem["id"])
                )
            else:
                cursor.execute(
                    "UPDATE driver_reminders SET is_sent = TRUE WHERE id = %s",
                    (rem["id"],)
                )
        if reminders:
            conn.commit()
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur reminders: {e}")
    finally:
        conn.close()

def job_compute_all_scores():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT cin FROM compte_driver WHERE fcm_token IS NOT NULL")
        drivers = cursor.fetchall()
        print(f">>> [SCHEDULER] Calcul scores pour {len(drivers)} conducteurs")
        for row in drivers:
            try:
                score_data = compute_weekly_score(row["cin"])
                _notify_weekly_score(row["cin"], score_data)
            except Exception as e:
                print(f">>> [SCHEDULER] Erreur score driver {row['cin']}: {e}")
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur job scores: {e}")
    finally:
        conn.close()

def _notify_weekly_score(cin: str, score_data: dict):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT fcm_token FROM compte_driver WHERE cin = %s", (cin,))
        row = cursor.fetchone()
        if not row or not row["fcm_token"]:
            return
        score = score_data["global_score"]
        if score >= 80:
            default_msg = "Excellente semaine ! Continuez comme ça."
        elif score >= 60:
            default_msg = "Bonne semaine, quelques points à améliorer."
        else:
            default_msg = "Semaine difficile, consultez votre rapport."
        tip = score_data.get("ai_report", {}).get("weekly_tip", default_msg)
        _send_fcm(
            token=row["fcm_token"],
            title=f"Votre score de conduite : {score}/100",
            body=tip,
            data={
                "type":       "weekly_score",
                "score":      str(score),
                "week_start": score_data.get("week_start", ""),
                "categories": json.dumps(score_data.get("categories", {})),
            },
            is_critical=False,
        )
    finally:
        conn.close()

def job_cleanup_old_alerts():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            DELETE FROM ai_diagnostics
            WHERE is_resolved = 1
              AND resolved_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
        """)
        deleted = cursor.rowcount
        conn.commit()
        print(f">>> [SCHEDULER] Nettoyage : {deleted} diagnostics supprimés")
    except Exception as e:
        print(f">>> [SCHEDULER] Erreur cleanup: {e}")
    finally:
        conn.close()

def job_check_expiring_documents():
    global _offense_reminder_sent, _doc_reminder_sent
    print(">>> [DOCS] Job démarré !")
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # ── DOCS normaux ──────────────────────────────────────────────────────
        cursor.execute("""
            SELECT e.id, e.driver_id, e.doc_type, e.end_date, d.fcm_token,
                   TIMESTAMPDIFF(SECOND, NOW(), e.end_date) AS seconds_left
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            WHERE e.doc_type IS NOT NULL AND e.doc_type != 'OFFENSE'
              AND e.end_date IS NOT NULL AND e.end_date > NOW()
              AND d.fcm_token IS NOT NULL
        """)
        docs = cursor.fetchall()
        print(f">>> [DOCS] {len(docs)} documents normaux trouvés")

        for doc in docs:
            seconds_left = doc["seconds_left"]
            event_id     = doc["id"]
            driver_id    = doc["driver_id"]

            # Vérifier si get_notif_preferences existe (deuxième code)
            if 'get_notif_preferences' in globals():
                prefs = get_notif_preferences(driver_id)
                raw_thresholds = prefs.get("reminder_thresholds", DEFAULT_THRESHOLDS)
                
                if not raw_thresholds:
                    print(f">>> [DOCS] Rappels désactivés pour {driver_id}, skip")
                    continue
                
                thresholds = _build_thresholds_for_driver(raw_thresholds)
                matched = _find_threshold(seconds_left, thresholds)
            else:
                # Utiliser les seuils par défaut
                matched = _find_threshold(seconds_left)

            if not matched:
                continue

            _, label, key = matched
            if _doc_reminder_sent.get(event_id) == key:
                continue

            _send_fcm(
                token=doc["fcm_token"],
                title=f"🔔 Document : {doc['doc_type']}",
                body=f"Votre {doc['doc_type']} expire {label}.",
                data={
                    "type":     "reminder",
                    "doc_type": doc["doc_type"],
                    "end_date": str(doc["end_date"]),
                },
                is_critical=False,
                code=0,
            )
            _doc_reminder_sent[event_id] = key
            print(f">>> [DOCS] ✅ Doc '{doc['doc_type']}' {label} → {driver_id}")

        # ── OFFENSES ──────────────────────────────────────────────────────────
        cursor.execute("""
            SELECT e.id, e.driver_id, e.doc_type, e.offense_type, e.offense_date,
                   e.paying, d.fcm_token,
                   TIMESTAMPDIFF(SECOND, NOW(), e.offense_date) AS seconds_left
            FROM events e
            JOIN compte_driver d ON d.cin = e.driver_id
            WHERE e.doc_type = 'OFFENSE'
              AND e.offense_date IS NOT NULL AND e.offense_date > NOW()
              AND d.fcm_token IS NOT NULL
        """)
        offenses = cursor.fetchall()
        print(f">>> [DOCS] {len(offenses)} offenses trouvées")

        for off in offenses:
            seconds_left = off["seconds_left"]
            event_id     = off["id"]
            driver_id    = off["driver_id"]
            offense_type = off["offense_type"] or "Infraction"
            paying       = off["paying"]
            amount_str   = f" — {paying} TND" if paying else ""

            # Même logique — préférences du driver
            if 'get_notif_preferences' in globals():
                prefs = get_notif_preferences(driver_id)
                raw_thresholds = prefs.get("reminder_thresholds", DEFAULT_THRESHOLDS)
                
                if not raw_thresholds:
                    print(f">>> [DOCS] Rappels désactivés pour {driver_id}, skip offense")
                    continue
                
                thresholds = _build_thresholds_for_driver(raw_thresholds)
                matched = _find_threshold(seconds_left, thresholds)
            else:
                matched = _find_threshold(seconds_left)

            if not matched:
                continue

            _, label, key = matched
            if _offense_reminder_sent.get(event_id) == key:
                continue

            _send_fcm(
                token=off["fcm_token"],
                title=f"⚠️ Infraction : {offense_type}",
                body=f"Paiement requis {label}{amount_str}.",
                data={
                    "type":         "reminder",
                    "doc_type":     "OFFENSE",
                    "offense_type": offense_type,
                    "offense_date": str(off["offense_date"]),
                    "paying":       str(paying or 0),
                },
                is_critical=False,
                code=0,
            )
            _offense_reminder_sent[event_id] = key
            print(f">>> [DOCS] ✅ Offense '{offense_type}' {label} → {driver_id}")

    except Exception as e:
        import traceback
        print(f">>> [DOCS] ERREUR: {e}")
        traceback.print_exc()
    finally:
        cursor.close()
        conn.close()

# ── Démarrage / arrêt ─────────────────────────────────────────────────────────

def start_scheduler():
    scheduler.add_job(job_process_events, "interval", seconds=30, id="process_events")
    scheduler.add_job(job_send_reminders, "interval", minutes=1, id="reminders")
    scheduler.add_job(job_compute_all_scores,
                      CronTrigger(day_of_week="mon", hour=6, minute=0), id="weekly_scores")
    scheduler.add_job(job_cleanup_old_alerts,
                      CronTrigger(day_of_week="sun", hour=0, minute=0), id="cleanup")

    if TEST_MODE:
        # 🧪 MODE TEST — toutes les 30 secondes
        scheduler.add_job(job_daily_report, "interval", seconds=30, id="daily_report")
        scheduler.add_job(job_check_vehicle_movement, "interval", seconds=30, id="vehicle_movement")
        scheduler.add_job(job_check_expiring_documents, "interval", seconds=30, id="expiring_docs")
        scheduler.add_job(job_check_fuel_reminders, "interval", seconds=30, id="fuel_reminders")
        scheduler.add_job(job_check_sav_km_reminders, "interval", seconds=30, id="sav_km_reminders")
    else:
        # ✅ MODE RÉEL
        scheduler.add_job(job_daily_report, CronTrigger(hour=20, minute=0), id="daily_report")
        scheduler.add_job(job_check_vehicle_movement, "interval", minutes=2, id="vehicle_movement")
        scheduler.add_job(job_check_expiring_documents, CronTrigger(hour=8, minute=0), id="expiring_docs")
        scheduler.add_job(job_check_fuel_reminders, CronTrigger(hour="*", minute="*/15"), id="fuel_reminders")
        scheduler.add_job(job_check_sav_km_reminders, CronTrigger(hour=8, minute=30), id="sav_km_reminders")

    scheduler.start()
    print(f">>> [SCHEDULER] Démarré — MODE {'TEST' if TEST_MODE else 'RÉEL'}")

def stop_scheduler():
    scheduler.shutdown()
    print(">>> [SCHEDULER] Arrêté")