# services/admin_service.py

import json
import secrets
import uuid
from datetime import datetime, timedelta
from db import get_connection


# ── Drivers ───────────────────────────────────────────────────────────────────

def get_all_drivers(status: str = "all") -> list:
    """
    Retourne la liste des drivers selon leur statut.
    status: 'all' | 'pending' | 'active'
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT
                cin, first_name, last_name, telephone, email,
                driver_medically, driving_training, driving_safe,
                driver_authorized, codeQR, language, vehicule_id
            FROM compte_driver
        """
        if status == "pending":
            query += " WHERE driver_authorized = 0"
        elif status == "active":
            query += " WHERE driver_authorized = 1"

        query += " ORDER BY cin ASC"

        cursor.execute(query)
        rows = cursor.fetchall()

        result = []
        for r in rows:
            r = dict(r)
            r["driver_authorized"] = bool(r.get("driver_authorized"))
            r["driver_medically"]  = bool(r.get("driver_medically"))
            r["driving_training"]  = bool(r.get("driving_training"))
            r["driving_safe"]      = bool(r.get("driving_safe"))
            result.append(r)

        return result
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_all_drivers: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def get_driver_detail(cin: str) -> dict | None:
    """
    Retourne le détail complet d'un driver avec ses devices associés.
    Retourne None si le driver n'existe pas.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        driver = cursor.fetchone()
        if not driver:
            return None

        cursor.execute("""
            SELECT dev.id, dev.serial,
                   dev.device_number, dev.stream_id,
                   v.mark, v.matricule, v.model
            FROM vehicule v
            JOIN compte_driver d ON d.vehicule_id = v.matricule
            LEFT JOIN device dev ON dev.vehicule_id = v.matricule
            WHERE d.cin = %s
        """, (cin,))
        devices = cursor.fetchall()

        driver = dict(driver)
        driver["driver_authorized"] = bool(driver.get("driver_authorized"))
        driver["driver_medically"]  = bool(driver.get("driver_medically"))
        driver["driving_training"]  = bool(driver.get("driving_training"))
        driver["driving_safe"]      = bool(driver.get("driving_safe"))
        driver["devices"] = [dict(d) for d in devices]

        return driver
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_driver_detail: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def driver_exists(cin: str) -> bool:
    """Vérifie qu'un driver existe en base."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT cin FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        return cursor.fetchone() is not None
    except Exception as e:
        print(f">>> [ADMIN] Erreur driver_exists: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


# ── Devices ───────────────────────────────────────────────────────────────────

def get_all_devices() -> list:
    """
    Retourne tous les boîtiers avec leur véhicule et driver associés.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                dev.id,
                dev.serial,
                dev.device_number,
                dev.stream_id,
                dev.vehicule_id,
                v.mark,
                v.model,
                v.matricule,
                d.cin        AS driver_cin,
                d.first_name,
                d.last_name
            FROM device dev
            LEFT JOIN compte_driver d  ON d.vehicule_id  = dev.vehicule_id
            LEFT JOIN vehicule v       ON v.matricule     = dev.vehicule_id
            ORDER BY dev.id DESC
        """)
        rows = cursor.fetchall()
        return [dict(r) for r in rows]
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_all_devices: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def get_device_qr_data(device_id: int) -> dict | None:
    """
    Retourne les données JSON à encoder dans le QR code du boîtier.
    Retourne None si le device n'existe pas.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id, serial, device_number FROM device WHERE id = %s",
            (device_id,)
        )
        device = cursor.fetchone()
        if not device:
            return None

        qr_payload = {
            "type":      "device",
            "serial":    device["serial"],
            "device_id": str(device["id"]),
        }
        return {
            "device_id":      device["id"],
            "serial":         device["serial"],
            "qr_payload":     qr_payload,
            "qr_json_string": json.dumps(qr_payload),
        }
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_device_qr_data: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


# ── Vendor Tokens ─────────────────────────────────────────────────────────────

def get_all_vendor_tokens() -> list:
    """Retourne tous les tokens revendeurs triés par date de création."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, vendor_id, token, uses_left, expires_at, created_at
            FROM vendor_token
            ORDER BY created_at DESC
        """)
        rows = cursor.fetchall()
        return [dict(r) for r in rows]
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_all_vendor_tokens: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def create_vendor_token(uses: int, days_valid: int, created_by: str) -> dict:
    """
    Génère un nouveau token revendeur avec un vendor_id unique.
    Retourne le token créé avec son QR payload.
    """
    vendor_id  = f"VND-{uuid.uuid4().hex[:8].upper()}"
    token_val  = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(days=days_valid)

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO vendor_token (vendor_id, token, uses_left, expires_at, created_at, created_by)
            VALUES (%s, %s, %s, %s, NOW(), %s)
        """, (vendor_id, token_val, uses, expires_at, created_by))
        token_id = cursor.lastrowid
        conn.commit()

        qr_payload = {"type": "vendor", "vendor_id": vendor_id, "token": token_val}
        return {
            "id":             token_id,
            "vendor_id":      vendor_id,
            "token":          token_val,
            "uses_left":      uses,
            "expires_at":     expires_at.isoformat(),
            "qr_payload":     qr_payload,
            "qr_json_string": json.dumps(qr_payload),
        }
    except Exception as e:
        conn.rollback()
        print(f">>> [ADMIN] Erreur create_vendor_token: {e}")
        raise e
    finally:
        cursor.close()
        conn.close()


def remove_vendor_token(token_id: int) -> bool:
    """Supprime un token revendeur. Retourne True si supprimé."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM vendor_token WHERE id = %s", (token_id,))
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        print(f">>> [ADMIN] Erreur remove_vendor_token: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


# ── Stats ─────────────────────────────────────────────────────────────────────

def get_dashboard_stats() -> dict:
    """
    Retourne les statistiques globales du dashboard admin :
    nombre de drivers (total, actifs, en attente), devices, tokens actifs.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT COUNT(*) AS total FROM compte_driver")
        total_drivers = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM compte_driver WHERE driver_authorized = 1")
        active_drivers = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM compte_driver WHERE driver_authorized = 0")
        pending_drivers = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM device")
        total_devices = cursor.fetchone()["total"]

        cursor.execute("""
            SELECT COUNT(*) AS total FROM vendor_token
            WHERE uses_left > 0 AND expires_at > NOW()
        """)
        active_tokens = cursor.fetchone()["total"]

        return {
            "total_drivers":        total_drivers,
            "active_drivers":       active_drivers,
            "pending_drivers":      pending_drivers,
            "total_devices":        total_devices,
            "active_vendor_tokens": active_tokens,
        }
    except Exception as e:
        print(f">>> [ADMIN] Erreur get_dashboard_stats: {e}")
        return {}
    finally:
        cursor.close()
        conn.close()