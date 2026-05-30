from db import get_connection
from models.compte_driver import CompteDriver
from models.sav import Sav, SavCreate, SavUpdate 


def get_sav_by_driver(cin: str) -> list:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return []

        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

        cursor.execute("""
            SELECT
                s.id_sav,
                s.date_reparation,
                s.maintenance_type,
                s.description,
                s.cost,
                s.vehicule_id
            FROM sav s
            WHERE s.vehicule_id = %s
            ORDER BY s.date_reparation DESC
        """, (matricule,))
        rows = cursor.fetchall()
        result = []
        for r in rows:
            sav = Sav(
                id_sav=r["id_sav"],
                date_reparation=r["date_reparation"],
                vehicule_id=r["vehicule_id"],
                maintenance_type=r["maintenance_type"],
                description=r["description"],
                cost=r["cost"],
            )
            entry = sav.model_dump()
            entry["garage"] = None
            result.append(entry)

        return result

    except Exception as e:
        print(f">>> [SAV] Erreur get_sav_by_driver: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def update_sav(id_sav: int, cin: str, data: SavUpdate) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return False

        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

        cursor.execute("""
            UPDATE sav SET
                maintenance_type = %s,
                description      = %s,
                cost             = %s,
                date_reparation  = %s
            WHERE id_sav = %s
            AND vehicule_id = %s
        """, (
            data.maintenance_type,
            data.description,
            data.cost,
            data.date_reparation,
            id_sav,
            matricule,
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
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return False

        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

        cursor.execute(
            "DELETE FROM sav WHERE id_sav = %s AND vehicule_id = %s",
            (id_sav, matricule),
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

def create_sav(cin: str, data: SavCreate) -> int:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return None  # controller lèvera le 404

        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

        garage_id = data.garage_id if data.garage_id is not None else 0
        cursor.execute("""
            INSERT INTO sav
                (maintenance_type, description,
                 cost, date_reparation, vehicule_id, garage_id)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            data.maintenance_type, data.description,
            data.cost, data.date_reparation, matricule, garage_id,
        ))
        conn.commit()
        return cursor.lastrowid

    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()
def get_maintenance_types() -> list:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT DISTINCT maintenance_type
            FROM sav
            WHERE maintenance_type IS NOT NULL
            ORDER BY maintenance_type
        """)
        rows = cursor.fetchall()
        types_db = [row["maintenance_type"] for row in rows]
        return types_db if types_db else [
            "Freinage", "Pneus", "Batterie",
            "Distribution", "Embrayage", "Moteur"
        ]
    finally:
        cursor.close()
        conn.close()