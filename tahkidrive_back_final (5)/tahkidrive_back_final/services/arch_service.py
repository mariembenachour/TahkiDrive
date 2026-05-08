# services/telemetry_service.py
# Nouveau schéma : compte_driver.vehicule_id → vehicule.matricule (FK directe)

from db import get_connection


def _get_matricule(cin: str) -> str | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        return row["vehicule_id"] if row else None
    finally:
        cursor.close()
        conn.close()


def _get_device_and_table(cin: str):
    matricule = _get_matricule(cin)
    if not matricule:
        return None, None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id FROM device WHERE vehicule_id = %s LIMIT 1", (matricule,)
        )
        device = cursor.fetchone()
        if not device:
            return None, None
        device_id = device["id"]
        return device_id, f"arch_{device_id}"
    finally:
        cursor.close()
        conn.close()


def calculate_odo_stats(cin: str):
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"SELECT odo, date FROM {table_name} ORDER BY date DESC LIMIT 1")
        last = cursor.fetchone()
        if not last:
            return None

        odo_latest = float(last["odo"])
        last_date  = last["date"]
        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
        date_end   = last_date.strftime("%Y-%m-%d") + " 23:59:59"

        cursor.execute(f"""
            SELECT MIN(odo) AS min_odo, MAX(odo) AS max_odo
            FROM {table_name}
            WHERE date BETWEEN %s AND %s
        """, (date_start, date_end))
        mm = cursor.fetchone()
        journalier = float(mm["max_odo"] - mm["min_odo"]) \
            if mm and mm["min_odo"] is not None else 0.0

        return {"odo": odo_latest, "journalier": journalier}
    finally:
        cursor.close()
        conn.close()


def get_fuel_stats(cin: str):
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"""
            SELECT fuel, tfu, date FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        last = cursor.fetchone()
        if not last:
            return None

        fuel_current = float(last["fuel"]) if last["fuel"] is not None else 0.0
        last_date    = last["date"]
        date_start   = last_date.strftime("%Y-%m-%d") + " 00:00:00"

        cursor.execute(f"""
            SELECT fuel FROM {table_name}
            WHERE date >= %s ORDER BY date ASC LIMIT 1
        """, (date_start,))
        first_today = cursor.fetchone()
        fuel_matin  = float(first_today["fuel"]) \
            if first_today and first_today["fuel"] is not None else fuel_current

        consumed_today = max(0.0, round(fuel_matin - fuel_current, 2))

        return {
            "remaining_fuel": fuel_current,
            "last_consumption": {
                "fuel": consumed_today,
                "date": str(last_date),
            },
        }
    finally:
        cursor.close()
        conn.close()