# services/path_service.py
from db import get_connection
from models.compte_driver import CompteDriver
from models.device import Device
from models.path import Path
from datetime import datetime, date, timedelta


# ── Helpers (même pattern que arch_service) ───────────────────────────────────

def _get_device_id(cin: str) -> str | None:
    """cin → vehicule_id → device_id"""
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        # 1. Récupère le vehicule_id du driver
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        row = cursor.fetchone()
        if not row:
            print(f">>> [PATH] Aucun driver pour cin={cin}")
            return None
        driver = CompteDriver(**row)

        # 2. Récupère le device lié au véhicule
        cursor.execute(
            "SELECT * FROM device WHERE vehicule_id = %s LIMIT 1",
            (driver.vehicule_id,)
        )
        row = cursor.fetchone()
        if not row:
            print(f">>> [PATH] Aucun device pour vehicule_id={driver.vehicule_id}")
            return None
        device = Device(**row)
        print(f">>> [PATH] device_id={device.id}")
        return device.id

    except Exception as e:
        print(f">>> [PATH] Erreur _get_device_id: {e}")
        return None
    finally:
        cursor.close()
        conn.close()



def get_recent_paths(cin: str, limit: int = 5, offset: int = 0) -> dict:
    device_id = _get_device_id(cin)
    if not device_id:
        return {"today": [], "yesterday": [], "older": []}

    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                id,
                device_id,
                begin_path_time,
                end_path_time,
                begin_path_latitude,
                begin_path_longitude,
                end_path_latitude,
                end_path_longitude
            FROM path
            WHERE device_id = %s
            ORDER BY begin_path_time DESC
            LIMIT %s OFFSET %s
        """, (device_id, limit, offset))  # ✅ pas de filtre date

        rows = cursor.fetchall()
        paths = [Path(**dict(row)) for row in rows]

        today     = date.today()
        yesterday = today - timedelta(days=1)

        grouped = {"today": [], "yesterday": [], "older": []}
        for path in paths:
            path_date = path.begin_path_time.date()
            if path_date == today:
                grouped["today"].append(path)
            elif path_date == yesterday:
                grouped["yesterday"].append(path)
            else:
                grouped["older"].append(path)

        return grouped

    except Exception as e:
        print(f">>> [PATH] Erreur get_recent_paths: {e}")
        return {"today": [], "yesterday": [], "older": []}
    finally:
        cursor.close()
        conn.close()

def get_path_by_id(cin: str, path_id: int) -> Path | None:
    """Retourne un trajet spécifique — vérifie que le device appartient au chauffeur."""
    device_id = _get_device_id(cin)
    if not device_id:
        return None

    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT * FROM path
            WHERE id = %s AND device_id = %s
            LIMIT 1
        """, (path_id, device_id))

        row = cursor.fetchone()
        if not row:
            return None

        return Path(**dict(row))

    except Exception as e:
        print(f">>> [PATH] Erreur get_path_by_id: {e}")
        return None
    finally:
        cursor.close()
        conn.close()