# services/battery_service.py
from db import get_connection

def get_battery_maintenance(user_id: int):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:

            # 1. Récupérer le vehicule_id
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

            # 2. Requête commune
            query = """
                SELECT 
                    bm.id              AS id,
                    bm.mark,
                    bm.voltage,
                    bm.amperage,
                    bm.type_battery,
                    bm.serie_number,
                    bm.expiration_date,
                    bm.odometre,
                    bm.observations,
                    bm.prix_htva,
                    bm.prix_tva,

                    m.id               AS maintenance_id,
                    m.maintenance_type,
                    m.date_operation,
                    m.cost,
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

                FROM battery_maintenance bm
                JOIN maintenance m ON bm.id_maintenance = m.id
                JOIN garage g      ON m.id_garage = g.id
                WHERE m.vehicule_id = %s
                ORDER BY m.date_operation DESC
            """

            # 3. Historique complet
            cursor.execute(query, (vehicule_id,))
            rows = cursor.fetchall()
            if not rows:
                return None, "Aucune maintenance batterie trouvée"

            def build_battery(row):
                return {
                    "id": row["id"],
                    "mark": row["mark"],
                    "voltage": row["voltage"],
                    "amperage": row["amperage"],
                    "type_battery": row["type_battery"],
                    "serie_number": row["serie_number"],
                    "expiration_date": row["expiration_date"],
                    "odometre": row["odometre"],
                    "observations": row["observations"],
                    "prix_htva": row["prix_htva"],
                    "prix_tva": row["prix_tva"],
                    "maintenance": {
                        "id": row["maintenance_id"],
                        "maintenance_type": row["maintenance_type"],
                        "date_operation": row["date_operation"],
                        "cost": row["cost"],
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

            historique = [build_battery(r) for r in rows]
            last = historique[0]  # premier = le plus récent

            return {"last": last, "historique": historique}, None

    except Exception as e:
        print(">>> EXCEPTION battery:", str(e))
        return None, str(e)
    finally:
        conn.close()