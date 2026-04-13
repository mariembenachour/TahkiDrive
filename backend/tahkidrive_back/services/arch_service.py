# services/odo_service.py
from db import get_connection
from datetime import timedelta


def calculate_odo_stats():
    conn = get_connection()
    cursor = conn.cursor()

    # Dernière valeur
    cursor.execute("SELECT odo, date FROM arch_700003 ORDER BY date DESC LIMIT 1")
    last = cursor.fetchone()
    if not last:
        conn.close()
        return None

    odo_latest, last_date = float(last['odo']), last['date']

    # Journalier
    date_start_day = last_date.strftime("%Y-%m-%d") + " 00:00:00"
    date_end_day   = last_date.strftime("%Y-%m-%d") + " 23:59:59"

    cursor.execute("""
        SELECT MIN(odo) as min_odo, MAX(odo) as max_odo FROM arch_700003
        WHERE date BETWEEN %s AND %s
    """, (date_start_day, date_end_day))
    min_max_day = cursor.fetchone()
    journalier = float(min_max_day['max_odo'] - min_max_day['min_odo']) if min_max_day['min_odo'] is not None else 0

    # Début de la période mensuelle = dernière date - 30 jours
    month_start = last_date - timedelta(days=30)


    conn.close()

    return {"odo": odo_latest, "journalier": journalier,}