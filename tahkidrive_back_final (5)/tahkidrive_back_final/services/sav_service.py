
# services/sav_service.py

from db import get_connection


def get_sav_by_driver(cin: str):
    """
    Retourne UNIQUEMENT les accidents du véhicule du driver
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # récupérer véhicule du driver
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1",
            (cin,)
        )
        row = cursor.fetchone()

        if not row or not row["vehicule_id"]:
            return []

        matricule = row["vehicule_id"]

        cursor.execute("""
            SELECT
                s.id_sav,
                s.date_reparation,
                s.type_sav,
                s.description,
                s.cost,
                s.vehicule_id,
                s.garage_id,
                g.nom       AS garage_nom,
                g.adresse   AS garage_adresse,
                g.telephone AS garage_telephone,
                g.rating    AS garage_rating
            FROM sav s
            LEFT JOIN garage g ON g.id = s.garage_id
            WHERE s.vehicule_id = %s
              AND s.type_sav = 'accident'
            ORDER BY s.date_reparation DESC
        """, (matricule,))

        rows = cursor.fetchall()
        return [dict(r) for r in rows]

    finally:
        cursor.close()
        conn.close() 
def update_sav(id_sav: int, cin: str, data: dict) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return False
        matricule = row["vehicule_id"]

        cursor.execute("""
            UPDATE sav SET
                type_sav        = %s,
                maintenance_type = %s,
                description     = %s,
                cost            = %s,
                date_reparation = %s,
                garage_id       = %s
            WHERE id_sav = %s
              AND vehicule_id = %s
        """, (
            data.get("type_sav"),
            data.get("maintenance_type"),
            data.get("description"),
            data.get("cost"),
            data.get("date_reparation"),
            data.get("garage_id") or 0,
            id_sav,
            matricule
        ))
        conn.commit()
        return cursor.rowcount > 0

    except Exception as e:
        conn.rollback()
        print(f">>> [SAV] Erreur update: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


def delete_sav(id_sav: int, cin: str) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return False
        matricule = row["vehicule_id"]

        cursor.execute(
            "DELETE FROM sav WHERE id_sav = %s AND vehicule_id = %s",
            (id_sav, matricule)
        )
        conn.commit()
        return cursor.rowcount > 0

    except Exception as e:
        conn.rollback()
        print(f">>> [SAV] Erreur delete: {e}")
        return False
    finally:
        cursor.close()
        conn.close()
