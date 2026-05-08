# services/vehicule_service.py
# Nouveau schéma :
#   compte_driver.vehicule_id  → vehicule.matricule  (FK directe, pas de table pivot)
#   device.vehicule_id         → vehicule.matricule
#   arch_{device_id}           → table de télémétrie

from db import get_connection
from services.maintenance_service import get_maintenance_by_type


# ── Helpers internes ──────────────────────────────────────────────────────────

def _get_matricule(cin: str) -> str | None:
    """Retourne le matricule du véhicule assigné au driver, ou None."""
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
    """Retourne (device_id, table_name) pour le véhicule du driver."""
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


# ── Véhicule(s) du driver ─────────────────────────────────────────────────────

def get_user_vehicule(cin: str):
    """
    Retourne le véhicule du driver avec ses events.
    (Un seul véhicule par driver dans le nouveau schéma.)
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT v.*
            FROM vehicule v
            JOIN compte_driver d ON d.vehicule_id = v.matricule
            WHERE d.cin = %s
            LIMIT 1
        """, (cin,))
        vehicule = cursor.fetchone()
        if not vehicule:
            return None

        vehicule = dict(vehicule)

        cursor.execute(
            "SELECT * FROM events WHERE driver_id = %s ORDER BY date DESC",
            (cin,)
        )
        vehicule["events"] = [dict(e) for e in cursor.fetchall()]

        return vehicule
    finally:
        cursor.close()
        conn.close()


# ── Télémétrie ────────────────────────────────────────────────────────────────

def calculate_odo_stats(cin: str):
    """Odomètre courant + km parcourus aujourd'hui."""
    device_id, table_name = _get_device_and_table(cin)
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
    """Carburant restant + consommé aujourd'hui."""
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

        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
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


def get_last_temp(cin: str):
    """Dernière température moteur disponible."""
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"""
            SELECT temp_engine FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        row = cursor.fetchone()
        return row["temp_engine"] if row and row["temp_engine"] is not None else None
    except Exception:
        return None
    finally:
        cursor.close()
        conn.close()


# ── Dashboard ─────────────────────────────────────────────────────────────────

def get_dashboard_data(cin: str):
    """Agrège les données clés pour l'écran d'accueil du driver."""

    def safe_last(result):
        if result and isinstance(result, dict):
            return result.get("last")
        return None

    return {
        "last_temp":          get_last_temp(cin),
        "last_battery":       safe_last(get_maintenance_by_type(cin, "Battery")),
        "last_oil_change":    safe_last(get_maintenance_by_type(cin, "Oil Change")),
        "brake_maintenance":  safe_last(get_maintenance_by_type(cin, "Brake")),
        "embrayage_maintenance": safe_last(get_maintenance_by_type(cin, "Embrayage")),
    }