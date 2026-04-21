from db import get_connection
from datetime import timedelta


def get_vehicule_id(user_id: int, vehicule_id: int = None) -> int | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if vehicule_id:
            cursor.execute("""
                SELECT vehicule_id FROM driver_vehicule
                WHERE driver_id = %s AND vehicule_id = %s
            """, (user_id, vehicule_id))
        else:
            cursor.execute("""
                SELECT vehicule_id FROM driver_vehicule
                WHERE driver_id = %s LIMIT 1
            """, (user_id,))
        row = cursor.fetchone()
        return row['vehicule_id'] if row else None
    finally:
        conn.close()


def _get_device_and_table(user_id: int, vehicule_id: int = None):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        vid = get_vehicule_id(user_id, vehicule_id)
        if not vid:
            return None, None

        cursor.execute("""
            SELECT id FROM device WHERE vehicule_id = %s LIMIT 1
        """, (vid,))
        device = cursor.fetchone()
        if not device:
            return None, None

        device_id = device['id']
        return device_id, f"arch_{device_id}"
    finally:
        conn.close()


def calculate_odo_stats(user_id: int, vehicule_id: int = None):
    device_id, table_name = _get_device_and_table(user_id, vehicule_id)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"""
            SELECT odo, date FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        last = cursor.fetchone()
        if not last:
            return None

        odo_latest = float(last['odo'])
        last_date  = last['date']

        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
        date_end   = last_date.strftime("%Y-%m-%d") + " 23:59:59"

        cursor.execute(f"""
            SELECT MIN(odo) as min_odo, MAX(odo) as max_odo
            FROM {table_name}
            WHERE date BETWEEN %s AND %s
        """, (date_start, date_end))
        min_max = cursor.fetchone()
        journalier = float(min_max['max_odo'] - min_max['min_odo']) \
            if min_max and min_max['min_odo'] is not None else 0.0

        return {"odo": odo_latest, "journalier": journalier}

    finally:
        conn.close()

def get_fuel_stats(user_id: int, vehicule_id: int = None):
    device_id, table_name = _get_device_and_table(user_id, vehicule_id)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        # ── Dernière valeur → fuel restant maintenant
        cursor.execute(f"""
            SELECT fuel, tfu, date
            FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        last = cursor.fetchone()
        if not last:
            return None

        fuel_current = float(last['fuel']) if last['fuel'] is not None else 0.0
        last_date    = last['date']

        # ── Première valeur du jour → fuel au début de la journée
        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
        cursor.execute(f"""
            SELECT fuel FROM {table_name}
            WHERE date >= %s
            ORDER BY date ASC LIMIT 1
        """, (date_start,))
        first_today = cursor.fetchone()
        fuel_matin = float(first_today['fuel']) if first_today and first_today['fuel'] is not None else fuel_current

        # ── Consommé aujourd'hui = fuel début jour - fuel maintenant
        consumed_today = max(0.0, round(fuel_matin - fuel_current, 2))

        return {
            "remaining_fuel": fuel_current,      # litres restants
            "last_consumption": {
                "fuel": consumed_today,           # litres consommés aujourd'hui
                "date": str(last_date),
            }
        }

    finally:
        conn.close()