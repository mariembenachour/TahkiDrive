from db import get_connection
from models.compte_driver import CompteDriver
from models.sav import Sav


def _get_matricule(cin: str) -> str | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row:
            return None
        driver = CompteDriver(**row)
        return driver.vehicule_id
    except Exception as e:
        print(f">>> [MAINTENANCE] Erreur _get_matricule: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def get_maintenance_by_type(cin: str, maintenance_type: str, matricule: str = None):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if not matricule:
            matricule = _get_matricule(cin)
        
        print(f">>> [MAINTENANCE] cin={cin} matricule={matricule} type={maintenance_type}")
        
        if not matricule:
            return None

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
            AND LOWER(s.maintenance_type) = LOWER(%s)
            ORDER BY s.date_reparation DESC
        """, (matricule, maintenance_type))

        rows = cursor.fetchall()
        print(f">>> [MAINTENANCE] rows trouvées: {len(rows)}")
        
        if not rows:
            return None

        def build(r) -> dict:
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
            return entry

        historique = [build(r) for r in rows]
        return {"last": historique[0], "historique": historique}

    except Exception as e:
        print(f">>> [MAINTENANCE] Erreur get_maintenance_by_type: {e}")
        return None
    finally:
        cursor.close()
        conn.close()