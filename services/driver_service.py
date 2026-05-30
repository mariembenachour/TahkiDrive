# services/driver_service.py
# Schéma : compte_driver (cin PK, vehicule_id FK direct)

from db import get_connection
from models.compte_driver import CompteDriver


def get_driver_by_cin(cin: str) -> CompteDriver | None:
    """
    Récupère le profil complet d'un driver.

    POURQUOI LE MODÈLE ICI :
      - La BD retourne un dict brut {"cin": "...", "email": "...", ...}
      - On le verse dans CompteDriver(**row) → objet structuré
      - Le controller reçoit un CompteDriver, pas un dict anonyme
      - Si un champ manque ou a le mauvais type → Pydantic lève une erreur claire
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
        # row est un dict brut → on le met dans le modèle
        # CompteDriver(**row) = CompteDriver(cin=row["cin"], email=row["email"], ...)
        return CompteDriver(**row)
    except Exception as e:
        print(f">>> [DRIVER] Erreur get_driver_by_cin: {e}")
        return None
    finally:
        cursor.close()
        conn.close()