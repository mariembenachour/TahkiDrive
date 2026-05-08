# services/maintenance_service.py
# Nouveau schéma :
#   sav(id_sav, vehicule_id, garage_id, date_panne, date_reparation, …)
#   Plus de table reparation — vehicule_id et garage_id sont directement dans sav.

from db import get_connection


def _get_matricule(cin: str) -> str | None:
    """Retourne le matricule du véhicule du driver."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        return row["vehicule_id"] if row else None
    finally:
        cursor.close()
        conn.close()


def get_maintenance_by_type(cin: str, maintenance_type: str, matricule: str = None):
    """
    Retourne { last, historique } pour un type de maintenance donné.
    Si matricule n'est pas fourni, il est résolu depuis le CIN du driver.
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

        def build(r):
            return {
                "id_sav":           r["id_sav"],
                "vehicule_id":      r["vehicule_id"],
                "garage_id":        r["garage_id"],
                "date_reparation":  r["date_reparation"],
                "type_sav":         r["type_sav"],
                "maintenance_type": r["maintenance_type"],
                "description":      r["description"],
                "cost":             r["cost"],
                "garage": {
                    "nom":       r["garage_nom"],
                    "telephone": r["garage_telephone"],
                    "adresse":   r["garage_adresse"],
                    "rating":    r["garage_rating"],
                    "latitude":  r["garage_latitude"],
                    "longitude": r["garage_longitude"],
                },
            }

        historique = [build(r) for r in rows]
        return {"last": historique[0], "historique": historique}

    finally:
        cursor.close()
        conn.close()