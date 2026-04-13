# services/fuel_service.py
from db import get_connection

def get_fuelings_by_device():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:

            # 1. Récupérer le dernier id_device depuis arch_700003
            cursor.execute("""
                SELECT id_device 
                FROM arch_700003 
                ORDER BY date DESC 
                LIMIT 1
            """)
            row = cursor.fetchone()
            print(">>> row arch_700003:", row)
            if not row:
                return None, "Aucun enregistrement dans arch_700003"
            
            id_device = row["id_device"]
            print(">>> id_device:", id_device)

            # 2. Récupérer le vehicle_id depuis device
            cursor.execute("""
                SELECT vehicule_id 
                FROM device 
                WHERE id = %s
            """, (id_device,))
            row = cursor.fetchone()
            print(">>> row device:", row)
            if not row:
                return None, f"Aucun véhicule trouvé pour le device {id_device}"
            
            id_vehicule = row["vehicule_id"]
            print(">>> id_vehicule:", id_vehicule)

            # 3. Récupérer tous les fuelings pour ce véhicule
            cursor.execute("""
                SELECT * 
                FROM fueling 
                WHERE id_vehicule = %s 
                ORDER BY date ASC
            """, (id_vehicule,))
            all_fuelings = cursor.fetchall()
            print(">>> all_fuelings count:", len(all_fuelings))

            # 4. Dernier fueling
            last_fueling = all_fuelings[-1] if all_fuelings else None
            print(">>> last_fueling:", last_fueling)

            # 5. Dernière consommation depuis arch_700003
            cursor.execute("""
                SELECT fuel, date 
                FROM arch_700003 
                WHERE id_device = %s 
                ORDER BY date DESC 
                LIMIT 1
            """, (id_device,))
            row = cursor.fetchone()
            print(">>> last_consumption row:", row)
            last_consumption = {"fuel": row["fuel"], "date": row["date"]} if row else None

            # 6. Calcul du carburant restant
            remaining = None
            if last_fueling and last_consumption:
                qty = last_fueling.get("quantity") or 0
                consumed = last_consumption.get("fuel") or 0
                remaining = qty - consumed
            print(">>> remaining_fuel:", remaining)

            return {
                "id_vehicule": id_vehicule,
                "id_device": id_device,
                "all_fuelings": all_fuelings,
                "last_fueling": last_fueling,
                "last_consumption": last_consumption,
                "remaining_fuel": remaining
            }, None

    except Exception as e:
        print(">>> EXCEPTION:", str(e))
        return None, str(e)
    finally:
        conn.close()