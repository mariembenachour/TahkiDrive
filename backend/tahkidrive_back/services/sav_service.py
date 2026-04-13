from db import get_connection


def get_sav_by_user_id(user_id: str, category: str = None):
    conn = get_connection()
    cursor = conn.cursor()

    query = """
        SELECT 
            sav.id              AS sav_id,
            sav.date            AS sav_date,
            sav.vehicule_id,
            sav.etat,
            sav.type,
            sav.description     AS sav_description,
            sav.id_garage,
            sav.date_repare
        FROM sav
        JOIN user_vehicule uv 
            ON uv.vehicule_id = sav.vehicule_id
        WHERE uv.user_id = %s
    """

    params = [user_id]

    # filtre optionnel
    if category in ["panne", "accident"]:
        query += " AND sav.type = %s "
        params.append(category)

    query += " ORDER BY sav.date DESC"

    cursor.execute(query, tuple(params))
    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    return rows