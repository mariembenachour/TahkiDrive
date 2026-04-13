from db import get_connection
from services.maintenance_service import get_maintenance_by_type

def get_user_vehicules(user_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT v.*, uv.user_id
            FROM vehicule v
            JOIN user_vehicule uv ON v.id = uv.vehicule_id
            WHERE uv.user_id = %s
        """, (user_id,))
        vehicules_data = cursor.fetchall()

        result = []

        for v in vehicules_data:
            vehicule = dict(v)
            cursor.execute("""
                SELECT d.*, 
                       p.id as provider_id,
                       p.name,
                       p.email,
                       p.telephone,
                       p.adresse,
                       p.codetva,
                       p.type as provider_type
                FROM document d
                LEFT JOIN provider p ON d.provider_id = p.id
                WHERE d.vehicule_id = %s
            """, (v['id'],))

            docs_data = cursor.fetchall()

            docs = []
            for d in docs_data:
                doc = dict(d)

                doc['provider'] = {
                    'id': d['provider_id'],
                    'name': d['name'],
                    'email': d['email'],
                    'telephone': d['telephone'],
                    'adresse': d['adresse'],
                    'codetva': d['codetva'],
                    'type': d['provider_type']
                }

                docs.append(doc)

            vehicule['docs'] = docs

            # ===================== FICHE VEHICULE (IMPORTANT 🔥) =====================
            cursor.execute("""
                SELECT *
                FROM fiche_vehicule
                WHERE id_vehicule = %s
            """, (v['id'],))

            fiche_data = cursor.fetchone()

            vehicule['fiche_vehicule'] = dict(fiche_data) if fiche_data else {}

            result.append(vehicule)

        return result

    finally:
        conn.close()


def get_vehicule_id(user_id: int, vehicule_id: int = None) -> int | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if vehicule_id:
            cursor.execute("""
                SELECT vehicule_id FROM user_vehicule
                WHERE user_id = %s AND vehicule_id = %s
            """, (user_id, vehicule_id))
        else:
            cursor.execute("""
                SELECT vehicule_id FROM user_vehicule
                WHERE user_id = %s
                LIMIT 1
            """, (user_id,))

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