# services/vehicule_service.py

from db import get_connection
from models.compte_driver import CompteDriver
from models.vehicule import Vehicule
from models.device import Device
from models.arch_700003 import Arch700003
from models.event import Event

from services.maintenance_service import get_maintenance_by_type


# ── Helpers internes ──────────────────────────────────────────────────────────

def _get_matricule(cin: str) -> str | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,))
        row = cursor.fetchone()
        if not row:
            return None
        driver = CompteDriver(**row)
        return driver.vehicule_id
    except Exception as e:
        print(f">>> [VEHICULE] Erreur _get_matricule: {e}")
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
            return None, None
        device = Device(**row)
        return device.id, f"arch_{device.id}"
    except Exception as e:
        print(f">>> [VEHICULE] Erreur _get_device_and_table: {e}")
        return None, None
    finally:
        cursor.close()
        conn.close()


# ── Véhicule du driver ────────────────────────────────────────────────────────

def get_user_vehicule(cin: str) -> dict | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT v.* FROM vehicule v
            JOIN compte_driver d ON d.vehicule_id = v.matricule
            WHERE d.cin = %s LIMIT 1
        """, (cin,))
        row = cursor.fetchone()
        if not row:
            return None

        vehicule = Vehicule(**row)
        result = vehicule.dict()

        cursor.execute(
            "SELECT * FROM events WHERE driver_id = %s ORDER BY date DESC", (cin,)
        )
        ev_rows = cursor.fetchall()
        result["events"] = []
        for ev_row in ev_rows:
            try:
                ev = Event(
                    id=ev_row["id"],
                    date=ev_row["date"],
                    subtype=ev_row["subtype"],
                    added_info=ev_row.get("added_info"),
                    driver_id=ev_row.get("driver_id"),
                    doc_type=ev_row.get("doc_type"),
                    end_date=ev_row.get("end_date"),
                    is_notified=bool(ev_row.get("is_notified")),
                    paying=ev_row.get("paying"),
                    offense_type=ev_row.get("offense_type"),
                    offense_date=ev_row.get("offense_date"),
                )
                result["events"].append(ev.dict())
            except Exception:
                result["events"].append(dict(ev_row))

        return result
    except Exception as e:
        print(f">>> [VEHICULE] Erreur get_user_vehicule: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


# ── Télémétrie ────────────────────────────────────────────────────────────────

def calculate_odo_stats(cin: str) -> dict | None:
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Lecture directe des champs utiles — pas SELECT * pour éviter
        # les erreurs Pydantic si des champs obligatoires sont NULL en BD
        cursor.execute(f"""
            SELECT odo, date FROM {table_name}
            WHERE id_device = %s AND odo IS NOT NULL AND odo > 0
            ORDER BY date DESC LIMIT 1
        """, (device_id,))
        row = cursor.fetchone()
        if not row:
            print(f">>> [VEHICULE] Aucune ligne odo dans {table_name}")
            return None

        odo_latest = float(row["odo"])
        last_date  = row["date"]
        date_start = last_date.strftime("%Y-%m-%d") + " 00:00:00"
        date_end   = last_date.strftime("%Y-%m-%d") + " 23:59:59"

        cursor.execute(f"""
            SELECT MIN(odo) AS min_odo, MAX(odo) AS max_odo
            FROM {table_name}
            WHERE id_device = %s AND date BETWEEN %s AND %s
        """, (device_id, date_start, date_end))
        mm = cursor.fetchone()
        journalier = (
            float(mm["max_odo"] - mm["min_odo"])
            if mm and mm["min_odo"] is not None else 0.0
        )
        return {"odo": odo_latest, "journalier": journalier}
    except Exception as e:
        print(f">>> [VEHICULE] Erreur calculate_odo_stats: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def get_fuel_stats(cin: str) -> dict | None:
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"""
            SELECT fuel, tfu, date FROM {table_name}
            WHERE id_device = %s
            ORDER BY date DESC LIMIT 1
        """, (device_id,))
        row = cursor.fetchone()
        if not row:
            return None

        fuel_current = float(row["fuel"]) if row["fuel"] is not None else 0.0
        last_date    = row["date"]
        date_start   = last_date.strftime("%Y-%m-%d") + " 00:00:00"

        cursor.execute(f"""
            SELECT fuel FROM {table_name}
            WHERE id_device = %s AND date >= %s
            ORDER BY date ASC LIMIT 1
        """, (device_id, date_start))
        first_row  = cursor.fetchone()
        fuel_matin = float(first_row["fuel"]) \
            if first_row and first_row["fuel"] is not None else fuel_current

        consumed_today = max(0.0, round(fuel_matin - fuel_current, 2))
        return {
            "remaining_fuel": fuel_current,
            "last_consumption": {"fuel": consumed_today, "date": str(last_date)},
        }
    except Exception as e:
        print(f">>> [VEHICULE] Erreur get_fuel_stats: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def get_last_temp(cin: str):
    """
    CORRECTION :
    Avant : SELECT * → Arch700003(**row) → si un champ obligatoire est NULL → Pydantic plante
    Maintenant : SELECT temp_engine uniquement → on lit juste ce dont on a besoin
    Règle : n'utilise le modèle complet que si tu as besoin de TOUS ses champs.
    Pour lire 1 champ → SELECT ce champ → retourne directement.
    """
    device_id, table_name = _get_device_and_table(cin)
    if not table_name:
        return None

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(f"""
            SELECT temp_engine FROM {table_name}
            WHERE id_device = %s AND temp_engine IS NOT NULL
            ORDER BY date DESC LIMIT 1
        """, (device_id,))
        row = cursor.fetchone()
        if not row:
            print(f">>> [VEHICULE] Aucune temp_engine dans {table_name}")
            return None
        return row["temp_engine"]
    except Exception as e:
        print(f">>> [VEHICULE] Erreur get_last_temp: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


# ── Dashboard ─────────────────────────────────────────────────────────────────

def get_dashboard_data(cin: str) -> dict:
    def safe_last(result):
        if result and isinstance(result, dict):
            return result.get("last")
        return None

    return {
        "last_temp":             get_last_temp(cin),
        "last_battery":          safe_last(get_maintenance_by_type(cin, "Battery")),
        "last_oil_change":       safe_last(get_maintenance_by_type(cin, "Oil Change")),
        "brake_maintenance":     safe_last(get_maintenance_by_type(cin, "Brake")),
        "embrayage_maintenance": safe_last(get_maintenance_by_type(cin, "Embrayage")),
    }