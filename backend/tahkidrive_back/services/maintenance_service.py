# services/maintenance_service.py
from db import get_connection


def get_maintenance_by_type(user_id: int, maintenance_type: str, vehicule_id: int = None):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # si pas de voiture envoyée → on prend 1 seule (celle du user)
        if not vehicule_id:
            cursor.execute("""
                SELECT vehicule_id 
                FROM user_vehicule
                WHERE user_id = %s
                LIMIT 1
            """, (user_id,))
            row = cursor.fetchone()
            if not row:
                return None, "Aucun véhicule trouvé"
            vehicule_id = row["vehicule_id"]

        cursor.execute("""
            SELECT 
                m.id,
                m.maintenance_type,
                m.cost,
                m.observation,
                m.date_operation,
                m.vehicule_id,
                m.labor_cost,
                m.actual_repair_time,
                g.id AS garage_id,
                g.nom,
                g.telephone,
                g.adresse,
                g.rating,
                g.latitude,
                g.longitude
            FROM maintenance m
            LEFT JOIN garage g ON m.id_garage = g.id
            WHERE m.vehicule_id = %s
              AND m.maintenance_type = %s
            ORDER BY m.date_operation DESC
        """, (vehicule_id, maintenance_type))

        rows = cursor.fetchall()

        if not rows:
            return None, f"Aucune maintenance {maintenance_type} trouvée"

        def build(r):
            return {
                "id": r["id"],
                "maintenance_type": r["maintenance_type"],
                "cost": r["cost"],
                "observation": r["observation"],
                "date_operation": r["date_operation"],
                "vehicule_id": r["vehicule_id"],
                "labor_cost": r["labor_cost"],
                "actual_repair_time": r["actual_repair_time"],
                "garage": {
                    "id": r["garage_id"],
                    "nom": r["nom"],
                    "telephone": r["telephone"],
                    "adresse": r["adresse"],
                    "rating": r["rating"],
                    "latitude": r["latitude"],
                    "longitude": r["longitude"],
                }
            }

        historique = [build(r) for r in rows]

        return {
            "last": historique[0],
            "historique": historique
        }, None

    finally:
        conn.close()