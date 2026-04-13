# services/tire_service.py
from db import get_connection

# Helper function
def to_int(value):
    if isinstance(value, bytes):
        # Méthode 1: prendre le premier octet
        return value[0]
        # Méthode 2: utiliser int.from_bytes
        # return int.from_bytes(value, byteorder='little')
    return value
def get_tire_maintenance(user_id: int):
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
                    t.id              AS id,
                    t.date_buy,
                    t.km_montage,
                    t.mark,
                    t.max_km,
                    t.position,
                    t.serie_number,
                    t.balancing,
                    t.calibration,
                    t.parallelism,
                    t.model,
                    t.type_pneu,
                    t.reference_unique,

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

                FROM tire_maintenance t
                JOIN maintenance m ON t.id_maintenance = m.id
                JOIN garage g      ON m.id_garage = g.id
                WHERE m.vehicule_id = %s
                ORDER BY m.date_operation DESC
            """, (vehicule_id,))

            rows = cursor.fetchall()
            if not rows:
                return None, "Aucune maintenance pneu trouvée"

            def build_tire(row):
                return {
                    "id": row["id"],
                    "date_buy": row["date_buy"],
                    "km_montage": row["km_montage"],
                    "mark": row["mark"],
                    "max_km": row["max_km"],
                    "position": row["position"],
                    "serie_number": row["serie_number"],
                     "balancing": to_int(row["balancing"]),      # ← conversion
                    "calibration": to_int(row["calibration"]),  # ← conversion
                    "parallelism": to_int(row["parallelism"]),  # ← conversion
                    "model": row["model"],
                    "type_pneu": row["type_pneu"],
                    "reference_unique": row["reference_unique"],
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

            historique = [build_tire(r) for r in rows]
            return {"last": historique[0], "historique": historique}, None

    except Exception as e:
        print(">>> EXCEPTION tire:", str(e))
        return None, str(e)
    finally:
        conn.close()