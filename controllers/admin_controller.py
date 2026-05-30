# controllers/admin_controller.py

import os
from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from services.auth_service import decode_token, get_admin_by_cin, activate_driver, block_driver
from services.admin_service import (
    get_all_drivers,
    get_driver_detail,
    driver_exists,
    get_all_devices,
    get_device_qr_data,
    get_all_vendor_tokens,
    create_vendor_token,
    remove_vendor_token,
    get_dashboard_stats,
)

router   = APIRouter(prefix="/admin", tags=["admin"])
security = HTTPBearer(auto_error=False)

IS_PROD = os.getenv("ENV", "dev") == "prod"


# ─── DEPENDENCY ADMIN ─────────────────────────────────────────────────────────

def get_admin_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials:
        try:
            payload = decode_token(credentials.credentials)
            cin     = payload.get("cin")
            scope   = payload.get("scope")
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
    return get_all_drivers(status)


@router.get("/drivers/{cin}")
def get_driver(cin: str, admin_id: str = Depends(get_admin_user)):
    """Détail complet d'un driver + ses devices."""
    driver = get_driver_detail(cin)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")
    return driver


@router.post("/drivers/{cin}/activate")
def activate_driver_account(cin: str, admin_id: str = Depends(get_admin_user)):
    """Activer le compte d'un driver (driver_authorized = 1)."""
    if not driver_exists(cin):
        raise HTTPException(status_code=404, detail="Driver introuvable")
    activate_driver(cin)
    return {"message": "Driver activé avec succès", "cin": cin}


@router.post("/drivers/{cin}/block")
def block_driver_account(cin: str, admin_id: str = Depends(get_admin_user)):
    """Bloquer le compte d'un driver (driver_authorized = 0)."""
    if not driver_exists(cin):
        raise HTTPException(status_code=404, detail="Driver introuvable")
    block_driver(cin)
    return {"message": "Driver bloqué", "cin": cin}


# ─── DEVICES ──────────────────────────────────────────────────────────────────

@router.get("/devices")
def list_devices(admin_id: str = Depends(get_admin_user)):
    """Lister tous les boîtiers avec leur véhicule et driver associé."""
    return get_all_devices()


@router.get("/devices/{device_id}/qr-data")
def get_device_qr(device_id: int, admin_id: str = Depends(get_admin_user)):
    """Retourne les données JSON à encoder dans le QR code du boîtier."""
    data = get_device_qr_data(device_id)
    if not data:
        raise HTTPException(status_code=404, detail="Device introuvable")
    return data


# ─── VENDOR TOKENS ────────────────────────────────────────────────────────────

@router.get("/vendor-tokens")
def list_vendor_tokens(admin_id: str = Depends(get_admin_user)):
    """Lister tous les tokens revendeurs."""
    return get_all_vendor_tokens()


@router.post("/vendor-tokens/generate")
async def generate_vendor_token(
    request: Request,
    admin_id: str = Depends(get_admin_user),
):
    """Générer un nouveau token revendeur avec son QR payload."""
    data       = await request.json()
    uses       = int(data.get("uses", 1))
    days_valid = int(data.get("days_valid", 365))
    return create_vendor_token(uses=uses, days_valid=days_valid, created_by=admin_id)


@router.delete("/vendor-tokens/{token_id}")
def delete_vendor_token(token_id: int, admin_id: str = Depends(get_admin_user)):
    """Supprimer un token revendeur."""
    remove_vendor_token(token_id)
    return {"message": "Token supprimé"}


# ─── STATS ────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(admin_id: str = Depends(get_admin_user)):
    """Statistiques globales du dashboard admin."""
    return get_dashboard_stats()