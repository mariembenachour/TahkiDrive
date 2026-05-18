# services/sav_service.py

from db import get_connection
from models.compte_driver import CompteDriver
from models.sav import Sav, SavUpdate
from models.garage import Garage


def get_sav_by_driver(cin: str) -> list:
    """
    Retourne UNIQUEMENT les accidents du véhicule du driver.

    POURQUOI LES MODÈLES ICI :
      - CompteDriver(**row) → pour lire vehicule_id proprement
      - Sav(**{...}) + Garage(**{...}) → pour structurer chaque résultat
      - On retourne .model_dump() car FastAPI attend un dict/JSON
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            return []

        # On utilise le modèle pour lire vehicule_id — pas row["vehicule_id"] brut
        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

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
        result = []
        for r in rows:
            # On construit le modèle Sav avec les champs sav
            sav = Sav(
                id_sav=r["id_sav"],
                date_reparation=r["date_reparation"],
                vehicule_id=r["vehicule_id"],
                garage_id=r["garage_id"],
                type_sav=r["type_sav"],
                description=r["description"],
                cost=r["cost"],
            )
            # On construit le modèle Garage avec les champs garage (si présent)
            garage = None
            if r["garage_nom"] is not None:
                garage = Garage(
                    id=r["garage_id"],
                    nom=r["garage_nom"],
                    telephone=r["garage_telephone"] or "",
                    adresse=r["garage_adresse"] or "",
                    latitude=0.0,
                    longitude=0.0,
                    rating=r["garage_rating"],
                )

            # On combine sav + garage dans un dict pour la réponse
            entry = sav.model_dump()
            entry["garage"] = garage.model_dump() if garage else None
            result.append(entry)

        return result

    except Exception as e:
        print(f">>> [SAV] Erreur get_sav_by_driver: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def update_sav(id_sav: int, cin: str, data: SavUpdate) -> bool:
    """
    data est maintenant un SavUpdate (modèle Pydantic) — plus un dict brut.
    Au lieu de data.get("type_sav"), on écrit data.type_sav directement.
    """
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
                type_sav         = %s,
                maintenance_type = %s,
                description      = %s,
                cost             = %s,
                date_reparation  = %s,
                garage_id        = %s
            WHERE id_sav = %s
              AND vehicule_id = %s
        """, (
            data.type_sav,
            data.maintenance_type,
            data.description,
            data.cost,
            data.date_reparation,
            data.garage_id or 0,
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