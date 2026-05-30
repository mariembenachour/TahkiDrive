# services/arch_service.py
from db import get_connection
from models.compte_driver import CompteDriver
from models.device import Device


def _get_matricule(cin: str) -> str | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,))
        row = cursor.fetchone()
        if not row:
            print(f">>> [ARCH] Aucun driver pour cin={cin}")
            return None
        driver = CompteDriver(**row)
        print(f">>> [ARCH] matricule trouvé: {driver.vehicule_id}")
        return driver.vehicule_id
    except Exception as e:
        print(f">>> [ARCH] Erreur _get_matricule: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def _get_device_and_table(cin: str):
    matricule = _get_matricule(cin)
    if not matricule:
        return None, None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device WHERE vehicule_id = %s LIMIT 1", (matricule,))
        row = cursor.fetchone()
        if not row:
            print(f">>> [ARCH] Aucun device pour matricule={matricule}")
            return None, None
        device = Device(**row)
        print(f">>> [ARCH] device_id={device.id} table=arch_{device.id}")
        return device.id, f"arch_{device.id}"
    except Exception as e:
        print(f">>> [ARCH] Erreur _get_device_and_table: {e}")
        return None, None
    finally:
        cursor.close()
        conn.close()


def calculate_odo_stats(cin: str):
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Vérifier que la table existe
        cursor.execute("""
            SELECT COUNT(*) AS cnt FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = %s
        """, (table_name,))
        if cursor.fetchone()["cnt"] == 0:
            print(f">>> [ARCH] Table {table_name} inexistante")
            return None

        cursor.execute(f"""
            SELECT odo, date FROM {table_name}
            WHERE odo IS NOT NULL AND odo > 0
            ORDER BY date DESC LIMIT 1
        """)
        row = cursor.fetchone()
        if not row:
            print(f">>> [ARCH] Aucune ligne odo dans {table_name}")
            return None

        odo_latest = float(row["odo"])
        last_date  = row["date"]
        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
        date_end   = last_date.strftime("%Y-%m-%d") + " 23:59:59"

        cursor.execute(f"""
            SELECT MIN(odo) AS min_odo, MAX(odo) AS max_odo
            FROM {table_name}
            WHERE date BETWEEN %s AND %s
        """, (date_start, date_end))
        mm = cursor.fetchone()
        journalier = float(mm["max_odo"] - mm["min_odo"]) \
            if mm and mm["min_odo"] is not None else 0.0

        return {"odo": odo_latest, "journalier": journalier}

    except Exception as e:
        print(f">>> [ARCH] Erreur calculate_odo_stats: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def get_fuel_stats(cin: str):
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT COUNT(*) AS cnt FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = %s
        """, (table_name,))
        if cursor.fetchone()["cnt"] == 0:
            print(f">>> [ARCH] Table {table_name} inexistante")
            return None

        cursor.execute(f"""
            SELECT fuel, tfu, date FROM {table_name}
            ORDER BY date DESC LIMIT 1
        """)
        row = cursor.fetchone()
        if not row:
            return None

        fuel_current = float(row["fuel"]) if row["fuel"] is not None else 0.0
        last_date    = row["date"]
        date_start   = last_date.strftime("%Y-%m-%d") + " 00:00:00"

        cursor.execute(f"""
            SELECT fuel FROM {table_name}
            WHERE date >= %s ORDER BY date ASC LIMIT 1
        """, (date_start,))
        first_today = cursor.fetchone()
        fuel_matin  = float(first_today["fuel"]) \
            if first_today and first_today["fuel"] is not None else fuel_current

        consumed_today = max(0.0, round(fuel_matin - fuel_current, 2))
        return {
            "remaining_fuel": fuel_current,
            "last_consumption": {"fuel": consumed_today, "date": str(last_date)},
        }

    except Exception as e:
        print(f">>> [ARCH] Erreur get_fuel_stats: {e}")
        return None
    finally:
        cursor.close()
        conn.close()