# services/distribution_service.py
from db import get_connection

def get_distribution_maintenance(user_id: int):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT vehicule_id 
                FROM user_vehicule 
                WHERE user_id = %s 
                LIMIT 1
            """, (user_id,))
            row = cursor.fetchone()
            if not row:
                return None, "Aucun véhicule trouvé pour cet utilisateur"

            vehicule_id = row["vehicule_id"]

            cursor.execute("""
                SELECT
                    d.id              AS id,
                    d.date_buy,
                    d.odometre,
                    d.cost,
                    d.mark,
                    d.next_odometre,
                    d.reference_unique,
                    d.type_piece,

                    m.id               AS maintenance_id,
                    m.maintenance_type,
                    m.date_operation,
                    m.cost             AS maintenance_cost,
                    m.labor_cost,
                    m.observation      AS maintenance_observation,
                    m.actual_repair_time,
                    m.vehicule_id,

                    g.id               AS garage_id,
                    g.nom,
                    g.telephone,
                    g.adresse,
                    g.rating,
                    g.latitude,
                    g.longitude

                FROM distribution_maintenance d
                JOIN maintenance m ON d.id_maintenance = m.id
                JOIN garage g      ON m.id_garage = g.id
                WHERE m.vehicule_id = %s
                ORDER BY m.date_operation DESC
            """, (vehicule_id,))

            rows = cursor.fetchall()
            if not rows:
                return None, "Aucune maintenance distribution trouvée"

            def build_distribution(row):
                return {
                    "id": row["id"],
                    "date_buy": row["date_buy"],
                    "odometre": row["odometre"],
                    "cost": row["cost"],
                    "mark": row["mark"],
                    "next_odometre": row["next_odometre"],
                    "reference_unique": row["reference_unique"],
                    "type_piece": row["type_piece"],
                    "maintenance": {
                        "id": row["maintenance_id"],
                        "maintenance_type": row["maintenance_type"],
                        "date_operation": row["date_operation"],
                        "cost": row["maintenance_cost"],
                        "labor_cost": row["labor_cost"],
                        "observation": row["maintenance_observation"],
                        "actual_repair_time": row["actual_repair_time"],
                        "vehicule_id": row["vehicule_id"],
                        "garage": {
                            "id": row["garage_id"],
                            "nom": row["nom"],
                            "telephone": row["telephone"],
                            "adresse": row["adresse"],
                            "rating": row["rating"],
                            "latitude": row["latitude"],
                            "longitude": row["longitude"],
                        }
                    }
                }

            historique = [build_distribution(r) for r in rows]
            last = historique[0]

            return {"last": last, "historique": historique}, None

    except Exception as e:
        print(">>> EXCEPTION distribution:", str(e))
        return None, str(e)
    finally:
        conn.close()