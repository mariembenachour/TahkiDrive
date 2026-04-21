from db import get_connection


def get_sav_by_user_id(driver_id: int, category: str = None):
    conn = get_connection()
    cursor = conn.cursor()

    query = """
        SELECT 
            sav.id_sav,
            sav.date_creation,
            r.id_vehicule AS vehicule_id,
            sav.etat,
            sav.type_sav,
            sav.description,
            r.id_garage,
            sav.actual_repair_time,
            sav.maintenance_type,
            sav.cost,
            sav.labor_cost,
            sav.odometre,
            sav.interval_km,
            sav.date_operation
        FROM sav
        LEFT JOIN reparation r
            ON r.id_sav = sav.id_sav
        JOIN driver_vehicule dv
            ON dv.vehicule_id = r.id_vehicule
        WHERE dv.driver_id = %s
        AND sav.type_sav IN ('panne', 'accident')
    """

    params = [driver_id]

    # filtre optionnel (mais sécurisé)
    if category in ["panne", "accident"]:
        query += " AND sav.type_sav = %s "
        params.append(category)

    query += " ORDER BY sav.date_creation DESC"

    cursor.execute(query, tuple(params))
    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    return rows