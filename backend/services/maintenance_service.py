# services/maintenance_service.py
# Schéma : sav(id_sav, vehicule_id, garage_id, date_reparation, …)

from db import get_connection
from models.compte_driver import CompteDriver
from models.sav import Sav
from models.garage import Garage


def _get_matricule(cin: str) -> str | None:
    """
    Retourne le matricule du véhicule du driver.

    POURQUOI LE MODÈLE :
      La BD retourne {"cin": "...", "vehicule_id": "TU123", ...}
      On met ça dans CompteDriver(**row) et on lit .vehicule_id
      C'est plus propre que row["vehicule_id"] et Pydantic valide le type.
    """
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
    """
    Retourne { last, historique } pour un type de maintenance donné.
    Si matricule n'est pas fourni, il est résolu depuis le CIN du driver.

    POURQUOI LES MODÈLES :
      - Sav(**{champs_sav}) → objet structuré pour chaque ligne sav
      - Garage(**{champs_garage}) → objet structuré pour le garage
      - .model_dump() → reconvertit en dict pour la réponse JSON
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if not matricule:
            matricule = _get_matricule(cin)
        if not matricule:
            return None

        cursor.execute("""
            SELECT
                s.id_sav,
                s.date_reparation,
                s.type_sav,
                s.maintenance_type,
                s.description,
                s.cost,
                s.vehicule_id,
                s.garage_id,
                g.nom          AS garage_nom,
                g.telephone    AS garage_telephone,
                g.adresse      AS garage_adresse,
                g.rating       AS garage_rating,
                g.latitude     AS garage_latitude,
                g.longitude    AS garage_longitude
            FROM sav s
            LEFT JOIN garage g ON g.id = s.garage_id
            WHERE s.vehicule_id = %s
            AND LOWER(s.maintenance_type) = LOWER(%s)
            ORDER BY s.date_reparation DESC
        """, (matricule, maintenance_type))

        rows = cursor.fetchall()
        if not rows:
            return None

        def build(r) -> dict:
            # Construire le modèle Sav avec les champs de la table sav
            sav = Sav(
                id_sav=r["id_sav"],
                date_reparation=r["date_reparation"],
                vehicule_id=r["vehicule_id"],
                garage_id=r["garage_id"],
                type_sav=r["type_sav"],
                maintenance_type=r["maintenance_type"],
                description=r["description"],
                cost=r["cost"],
            )

            # Construire le modèle Garage avec les champs du LEFT JOIN
            garage = None
            if r["garage_nom"] is not None:
                garage = Garage(
                    id=r["garage_id"],
                    nom=r["garage_nom"],
                    telephone=r["garage_telephone"] or "",
                    adresse=r["garage_adresse"] or "",
                    latitude=float(r["garage_latitude"] or 0),
                    longitude=float(r["garage_longitude"] or 0),
                    rating=r["garage_rating"],
                )

            # .model_dump() → reconvertit en dict pour pouvoir ajouter "garage"
            entry = sav.model_dump()
            entry["garage"] = garage.model_dump() if garage else None
            return entry

        historique = [build(r) for r in rows]
        return {"last": historique[0], "historique": historique}

    except Exception as e:
        print(f">>> [MAINTENANCE] Erreur get_maintenance_by_type: {e}")
        return None
    finally:
        cursor.close()
        conn.close()