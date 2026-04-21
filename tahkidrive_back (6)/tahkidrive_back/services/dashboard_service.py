from db import get_connection
from services.maintenance_service import get_maintenance_by_type
def get_user_vehicules(user_id: int):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        driver_id = user_id  # logique directe

        cursor.execute("""
            SELECT v.*, dv.driver_id
            FROM vehicule v
            JOIN driver_vehicule dv ON v.id = dv.vehicule_id
            WHERE dv.driver_id = %s
        """, (driver_id,))

        vehicules_data = cursor.fetchall()

        result = []

        for v in vehicules_data:
            vehicule = dict(v)

            cursor.execute("""
                SELECT *
                FROM events
                WHERE driver_id = %s
            """, (driver_id,))

            vehicule["events"] = [dict(e) for e in cursor.fetchall()]

            result.append(vehicule)

        return result

    finally:
        conn.close()


def get_vehicule_id(driver_id: int, vehicule_id: int = None) -> int | None:
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # si un véhicule est donné → vérifier qu’il appartient au driver
        if vehicule_id:
            cursor.execute("""
                SELECT vehicule_id
                FROM driver_vehicule
                WHERE driver_id = %s AND vehicule_id = %s
            """, (driver_id, vehicule_id))

        # sinon → prendre le premier véhicule du driver
        else:
            cursor.execute("""
                SELECT vehicule_id
                FROM driver_vehicule
                WHERE driver_id = %s
                LIMIT 1
            """, (driver_id,))

        row = cursor.fetchone()

        return row["vehicule_id"] if row else None

    finally:
        conn.close()


def get_last_temp(user_id: int, vehicule_id: int = None):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        vid = get_vehicule_id(user_id, vehicule_id)
        if not vid:
            return None

        cursor.execute("""
            SELECT id FROM device WHERE vehicule_id = %s LIMIT 1
        """, (vid,))
        device = cursor.fetchone()
        if not device:
            return None

        table_name = f"arch_{device['id']}"

        cursor.execute(f"""
            SELECT temp FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        row = cursor.fetchone()
        return row["temp"] if row and row["temp"] is not None else None
    finally:
        conn.close()


# =========================
# DASHBOARD CLEAN (IMPORTANT 🔥)
# =========================
def get_dashboard_data(user_id: int, vehicule_id: int = None):
    return {
        "last_temp": get_last_temp(user_id, vehicule_id),

        "last_battery": get_maintenance_by_type(user_id, "Battery", vehicule_id)[0]["last"]
            if get_maintenance_by_type(user_id, "Battery", vehicule_id)[0] else None,

        "last_oil_change": get_maintenance_by_type(user_id, "Oil Change", vehicule_id)[0]["last"]
            if get_maintenance_by_type(user_id, "Oil Change", vehicule_id)[0] else None,

        "brake_maintenance": get_maintenance_by_type(user_id, "Brake", vehicule_id)[0]["last"]
            if get_maintenance_by_type(user_id, "Brake", vehicule_id)[0] else None,

        "embrayage_maintenance": get_maintenance_by_type(user_id, "Embrayage", vehicule_id)[0]["last"]
            if get_maintenance_by_type(user_id, "Embrayage", vehicule_id)[0] else None,
    }