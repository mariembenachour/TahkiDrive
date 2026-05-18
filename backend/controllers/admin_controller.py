import json
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from db import get_connection
from services.auth_service import (
    decode_token, get_admin_by_cin,
    activate_driver, block_driver,
)
import os
import uuid

router = APIRouter(prefix="/admin", tags=["admin"])
security = HTTPBearer(auto_error=False)

IS_PROD = os.getenv("ENV", "dev") == "prod"


# ─── DEPENDENCY ADMIN ─────────────────────────────────────────────────────────

def get_admin_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials:
        try:
            payload = decode_token(credentials.credentials)
            cin   = payload.get("cin")
            scope = payload.get("scope")
            if cin and scope == "admin":
                admin = get_admin_by_cin(cin)
                if admin:
                    return cin
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")
    return "ADMIN_DEV"


# ─── DRIVERS ──────────────────────────────────────────────────────────────────

@router.get("/drivers")
def list_drivers(status: str = "all", admin_id: str = Depends(get_admin_user)):
    """
    Lister tous les drivers.
    status: 'all' | 'pending' | 'active'
    """
    conn = get_connection()
    cursor = conn.cursor()

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
    cursor.close()
    conn.close()

    result = []
    for r in rows:
        r = dict(r)
        r["driver_authorized"] = bool(r.get("driver_authorized"))
        r["driver_medically"]  = bool(r.get("driver_medically"))
        r["driving_training"]  = bool(r.get("driving_training"))
        r["driving_safe"]      = bool(r.get("driving_safe"))
        result.append(r)

    return result


@router.get("/drivers/{cin}")
def get_driver_detail(cin: str, admin_id: str = Depends(get_admin_user)):
    """Détail complet d'un driver + son device."""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
    )
    driver = cursor.fetchone()

    if not driver:
        cursor.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Driver introuvable")

    # Device lié via vehicule_id du driver → vehicule.matricule → device
    cursor.execute("""
        SELECT dev.id, dev.serial, dev.imei, dev.icc,
               dev.device_number, dev.stream_id,
               v.mark, v.matricule, v.model
        FROM vehicule v
        JOIN compte_driver d ON d.vehicule_id = v.matricule
        LEFT JOIN device dev ON dev.vehicule_id = v.matricule
        WHERE d.cin = %s
    """, (cin,))
    devices = cursor.fetchall()

    cursor.close()
    conn.close()

    driver = dict(driver)
    driver["driver_authorized"] = bool(driver.get("driver_authorized"))
    driver["driver_medically"]  = bool(driver.get("driver_medically"))
    driver["driving_training"]  = bool(driver.get("driving_training"))
    driver["driving_safe"]      = bool(driver.get("driving_safe"))
    driver["devices"] = [dict(d) for d in devices]

    return driver


@router.post("/drivers/{cin}/activate")
def activate_driver_account(cin: str, admin_id: str = Depends(get_admin_user)):
    """Activer le compte d'un driver (driver_authorized = 1)."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT cin FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
    )
    driver = cursor.fetchone()
    cursor.close()
    conn.close()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")

    activate_driver(cin)
    return {"message": "Driver activé avec succès", "cin": cin}


@router.post("/drivers/{cin}/block")
def block_driver_account(cin: str, admin_id: str = Depends(get_admin_user)):
    """Bloquer le compte d'un driver (driver_authorized = 0)."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT cin FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
    )
    driver = cursor.fetchone()
    cursor.close()
    conn.close()

    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")

    block_driver(cin)
    return {"message": "Driver bloqué", "cin": cin}


# ─── DEVICES ──────────────────────────────────────────────────────────────────

@router.get("/devices")
def list_devices(admin_id: str = Depends(get_admin_user)):
    """Lister tous les boitiers avec leur véhicule et driver associé."""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT
        dev.id,
        dev.serial,
        dev.imei,
        dev.icc,
        dev.device_number,
        dev.stream_id,
        dev.vehicule_id,
        v.mark,
        v.model,
        v.matricule,
        d.cin AS driver_cin,
        d.first_name,
        d.last_name FROM device dev
        LEFT JOIN compte_driver d
        ON d.vehicule_id = dev.vehicule_id
        LEFT JOIN vehicule v
        ON v.matricule = dev.vehicule_id 
        ORDER BY dev.id DESC """)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    return [dict(r) for r in rows]


@router.get("/devices/{device_id}/qr-data")
def get_device_qr_data(device_id: int, admin_id: str = Depends(get_admin_user)):
    """Retourne les données JSON à encoder dans le QR du boitier."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, serial, imei, device_number FROM device WHERE id = %s",
        (device_id,)
    )
    device = cursor.fetchone()
    cursor.close()
    conn.close()

    if not device:
        raise HTTPException(status_code=404, detail="Device introuvable")

    qr_payload = {
        "type":      "device",
        "serial":    device["serial"],
        "device_id": str(device["id"]),
    }
    return {
        "device_id":       device["id"],
        "serial":          device["serial"],
        "qr_payload":      qr_payload,
        "qr_json_string":  json.dumps(qr_payload),
    }


# ─── VENDOR TOKENS ────────────────────────────────────────────────────────────

@router.get("/vendor-tokens")
def list_vendor_tokens(admin_id: str = Depends(get_admin_user)):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, vendor_id, token, uses_left, expires_at, created_at
        FROM vendor_token
        ORDER BY created_at DESC
    """)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [dict(r) for r in rows]



@router.post("/vendor-tokens/generate")
async def generate_vendor_token(
    request: Request,
    admin_id: str = Depends(get_admin_user)
):
    data       = await request.json()
    uses       = int(data.get("uses", 1))
    days_valid = int(data.get("days_valid", 365))

    # ✅ ID généré automatiquement — plus besoin de l'envoyer
    vendor_id  = f"VND-{uuid.uuid4().hex[:8].upper()}"

    token_val  = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(days=days_valid)

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO vendor_token (vendor_id, token, uses_left, expires_at, created_at, created_by)
        VALUES (%s, %s, %s, %s, NOW(), %s)
    """, (vendor_id, token_val, uses, expires_at, admin_id))
    token_id = cursor.lastrowid
    conn.commit()
    cursor.close()
    conn.close()

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

@router.delete("/vendor-tokens/{token_id}")
def delete_vendor_token(token_id: int, admin_id: str = Depends(get_admin_user)):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM vendor_token WHERE id = %s", (token_id,))
    conn.commit()
    cursor.close()
    conn.close()
    return {"message": "Token supprimé"}


# ─── STATS ────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(admin_id: str = Depends(get_admin_user)):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as total FROM compte_driver")
    total_drivers = cursor.fetchone()["total"]

    cursor.execute("SELECT COUNT(*) as total FROM compte_driver WHERE driver_authorized = 1")
    active_drivers = cursor.fetchone()["total"]

    cursor.execute("SELECT COUNT(*) as total FROM compte_driver WHERE driver_authorized = 0")
    pending_drivers = cursor.fetchone()["total"]

    cursor.execute("SELECT COUNT(*) as total FROM device")
    total_devices = cursor.fetchone()["total"]

    cursor.execute("""
        SELECT COUNT(*) as total FROM vendor_token
        WHERE uses_left > 0 AND expires_at > NOW()
    """)
    active_tokens = cursor.fetchone()["total"]

    cursor.close()
    conn.close()

    return {
        "total_drivers":        total_drivers,
        "active_drivers":       active_drivers,
        "pending_drivers":      pending_drivers,
        "total_devices":        total_devices,
        "active_vendor_tokens": active_tokens,
    }