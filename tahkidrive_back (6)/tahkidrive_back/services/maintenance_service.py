# services/maintenance_service.py
from db import get_connection

def get_maintenance_by_type(user_id: int, maintenance_type: str, vehicule_id: int = None):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # 1. récupérer un véhicule du driver
        if not vehicule_id:
            cursor.execute("""
                SELECT vehicule_id
                FROM driver_vehicule
                WHERE driver_id = %s
                LIMIT 1
            """, (user_id,))
            row = cursor.fetchone()

            if not row:
                return None, "Aucun véhicule trouvé"

            vehicule_id = row["vehicule_id"]

        # 2. récupérer les réparations (AJOUT DE LA JOIN AVEC SAV ICI)
        cursor.execute("""
            SELECT
                r.id_sav,
                r.id_vehicule,
                r.id_garage,
                r.date_reparation,
                g.nom,
                g.telephone,
                g.adresse,
                g.rating,
                g.latitude,
                g.longitude,
                s.date_creation,
                s.etat,
                s.type_sav,
                s.maintenance_type,
                s.description,
                s.cost,
                s.labor_cost,
                s.odometre,
                s.interval_km,
                s.date_operation,
                s.actual_repair_time
            FROM reparation r
            LEFT JOIN garage g ON r.id_garage = g.id
            INNER JOIN sav s ON r.id_sav = s.id_sav
            WHERE r.id_vehicule = %s AND s.maintenance_type = %s
            ORDER BY r.date_reparation DESC
        """, (vehicule_id, maintenance_type))

        rows = cursor.fetchall()

        if not rows:
            return None, "Aucune réparation trouvée"

        def build(r):
            return {
                "id_sav": r["id_sav"],
                "vehicule_id": r["id_vehicule"],
                "garage_id": r["id_garage"],
                "date_reparation": r["date_reparation"],
                "garage": {
                    "nom": r["nom"],
                    "telephone": r["telephone"],
                    "adresse": r["adresse"],
                    "rating": r["rating"],
                    "latitude": r["latitude"],
                    "longitude": r["longitude"],
                },
                # Champs manquants ajoutés depuis la table sav
                "etat": r["etat"],
                "type_sav": r["type_sav"],
                "maintenance_type": r["maintenance_type"],
                "description": r["description"],
                "cost": r["cost"],
                "labor_cost": r["labor_cost"],
                "odometre": r["odometre"],
                "interval_km": r["interval_km"],
                "date_operation": r["date_operation"],
                "actual_repair_time": r["actual_repair_time"]
            }

        historique = [build(r) for r in rows]

        return {
            "last": historique[0],
            "historique": historique
        }, None

    finally:
        conn.close()