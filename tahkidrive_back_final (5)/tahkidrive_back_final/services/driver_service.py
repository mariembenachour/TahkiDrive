# services/driver_service.py
# Nouveau schéma : compte_driver (cin PK, vehicule_id FK direct)
# Plus de table driver_vehicule ni de table user séparée.

from db import get_connection


def get_driver_by_cin(cin: str):
    """Récupère le profil complet d'un driver."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()