# auth_controller.py
import json
from fastapi import APIRouter, Request, HTTPException, Depends, Body
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.auth_service import (
    get_driver_by_email, get_driver_by_cin,
    get_admin_by_email,
    verify_password,
    create_setup_token, create_access_token, create_admin_token,
    decode_token,
    get_vendor_token, decrement_vendor_token,
    get_device_by_serial,
    is_vehicule_already_linked,
    create_driver, link_vehicule_to_driver, update_driver_profile,get_device_mode,update_fcm_token 
)
from db import get_connection
import os
from dependencies import get_current_user, security
from models.auth import LoginRequest, AdminLoginRequest, UpdateProfileRequest
from models.compte_driver import CompteDriverPublic
router = APIRouter(prefix="/auth", tags=["auth"])
IS_PROD = os.getenv("ENV", "dev") == "prod"


# ─── LOGIN DRIVER ────────────────────────────────────────────────────────────

@router.post("/login/driver")
async def login_driver(login_data: LoginRequest):
    """
    CORRECTION :
    Avant : driver["password"], driver["cin"] → plante car driver est un CompteDriver
    Maintenant : driver.password, driver.cin → accès via attributs du modèle Pydantic
    """
    email    = login_data.email.strip()
    password = login_data.password

    if not email or not password:
        raise HTTPException(status_code=400, detail="email et password requis")

    # get_driver_by_email retourne un CompteDriver (modèle Pydantic), pas un dict
    driver = get_driver_by_email(email)
    if not driver:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    # driver.password au lieu de driver["password"]
    pwd_ok = verify_password(password, driver.password) or (password == driver.password)
    if not pwd_ok:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    # driver.driver_authorized au lieu de driver["driver_authorized"]
    if not driver.driver_authorized:
        raise HTTPException(status_code=403, detail="Compte en attente de validation admin")

    token = create_access_token(driver.cin)
    mode = get_device_mode(driver.cin)
    return {
        "access_token": token,
        "has_cam":     mode["has_cam"],
        "has_boitier": mode["has_boitier"],
        "token_type":   "bearer",
        "cin":          driver.cin,
        "driver": {
            "cin":               driver.cin,
            "first_name":        driver.first_name,
            "last_name":         driver.last_name,
            "email":             driver.email,
            "language":          driver.language,
            "driver_authorized": bool(driver.driver_authorized),
        },
    }


# ─── LOGIN ADMIN ─────────────────────────────────────────────────────────────

@router.post("/login/admin")
async def login_admin(login_data: AdminLoginRequest):
    """
    Même correction : admin.password, admin.cin au lieu de admin["password"]
    """
    email    = login_data.email.strip()
    password = login_data.password

    if not email or not password:
        raise HTTPException(status_code=400, detail="email et password requis")

    # get_admin_by_email retourne un Administrateur (modèle Pydantic)
    admin = get_admin_by_email(email)
    if not admin:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    # admin.password au lieu de admin["password"]
    pwd_ok = verify_password(password, admin.password) or (password == admin.password)
    if not pwd_ok:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    token = create_admin_token(admin.cin)
    return {
        "access_token": token,
        "token_type":   "bearer",
        "cin":          admin.cin,
    }


# ─── SCAN QR + REGISTER DRIVER ───────────────────────────────────────────────

@router.post("/scan-register")
async def scan_register(request: Request):
    try:
        data = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Body JSON invalide")

    device_qr_raw = data.get("device_qr_data", "")
    vendor_qr_raw = data.get("vendor_qr_data", "")
    cin           = data.get("cin", "").strip()
    email         = data.get("email", "").strip()
    password      = data.get("password", "")
    fcm_token     = data.get("fcm_token", "")
    language      = data.get("language", "fr")

    if not cin or not email or not password:
        raise HTTPException(status_code=400, detail="cin, email et password requis")

    if get_driver_by_cin(cin):
        raise HTTPException(status_code=409, detail="Ce CIN est déjà enregistré")

    if get_driver_by_email(email):
        raise HTTPException(status_code=409, detail="Cet email est déjà utilisé")

    # Parse QR Boitier
    try:
        device_data = json.loads(device_qr_raw)
    except Exception:
        device_data = {"serial": device_qr_raw}

    serial = device_data.get("serial", "").strip()
    if not serial:
        raise HTTPException(status_code=400, detail="QR boitier invalide : serial manquant")

    # get_device_by_serial retourne un Device (modèle Pydantic)
    device = get_device_by_serial(serial)
    if not device:
        raise HTTPException(status_code=404, detail=f"Boitier introuvable pour le serial : {serial}")

    # device.vehicule_id au lieu de device.get("vehicule_id")
    matricule = device.vehicule_id or ""
    print("serial =", serial)
    print("device =", device)
    print("matricule envoyé =", repr(matricule))
    print("linked =", is_vehicule_already_linked(matricule))

    if matricule and is_vehicule_already_linked(matricule, exclude_cin=cin):
        return {
            "status":  "already_linked",
            "message": "Ce véhicule est déjà associé à un compte",
        }

    # Parse QR Revendeur
    try:
        vendor_data = json.loads(vendor_qr_raw)
    except Exception:
        vendor_data = {"token": vendor_qr_raw}

    vendor_id = vendor_data.get("vendor_id", "").strip()
    token_val = vendor_data.get("token", "").strip()

    if not vendor_id or not token_val:
        raise HTTPException(status_code=400, detail="QR revendeur invalide")

    # get_vendor_token retourne un VendorToken (modèle Pydantic)
    vendor_token = get_vendor_token(vendor_id, token_val)
    if not vendor_token:
        raise HTTPException(status_code=403, detail="Token revendeur invalide ou expiré")

    code_qr = device_qr_raw
    create_driver(
        cin=cin, email=email, password=password,
        fcm_token=fcm_token, language=language, code_qr=code_qr,
    )

    if matricule:
        link_vehicule_to_driver(cin, matricule)

    # vendor_token.id au lieu de vendor_token["id"]
    decrement_vendor_token(vendor_token.id)

    setup_token = create_setup_token(cin)
    return {
        "message":     "Compte créé. Complétez votre profil.",
        "setup_token": setup_token,
        "cin":         cin,
    }


# ─── SETUP PROFIL ────────────────────────────────────────────────────────────

@router.patch("/setup-profile")
async def setup_profile(request: Request, cin: str = Depends(get_current_user)):
    try:
        data = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Body JSON invalide")

    required = ["first_name", "last_name", "telephone"]
    for field in required:
        if not data.get(field):
            raise HTTPException(status_code=400, detail=f"Champ manquant : {field}")

    # update_driver_profile attend un UpdateProfileRequest
    profile = UpdateProfileRequest(**data)
    update_driver_profile(cin, profile)
    access_token = create_access_token(cin)
    return {
            "message": "Profil soumis. En attente de validation admin.",
            "status": "pending",
            "access_token": access_token,  # ← AJOUTE ÇA
            "cin": cin
        }

# ─── STATUS ──────────────────────────────────────────────────────────────────

@router.get("/status")
def check_status(cin: str = Depends(get_current_user)):
    # get_driver_by_cin retourne un CompteDriver (modèle Pydantic)
    driver = get_driver_by_cin(cin)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")

    # driver.driver_authorized au lieu de driver["driver_authorized"]
    if bool(driver.driver_authorized):
        return {
            "activated":    True,
            "access_token": create_access_token(cin),
            "cin":          cin,
        }
    return {"activated": False, "message": "En attente de validation admin"}


# ─── ME ──────────────────────────────────────────────────────────────────────

@router.get("/me")
def get_me(cin: str = Depends(get_current_user)):
    driver = get_driver_by_cin(cin)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")

    # driver est un CompteDriver → CompteDriverPublic pour ne pas exposer le password
    public = CompteDriverPublic(**driver.model_dump())
    return {"driver": public.model_dump()}


# ─── UPDATE PROFILE ──────────────────────────────────────────────────────────

@router.put("/update-profile")
async def update_profile(
    data: dict = Body(...),
    cin: str = Depends(get_current_user),
):
    if not data:
        raise HTTPException(status_code=400, detail="Body vide")

    # On construit un UpdateProfileRequest depuis le dict reçu
    try:
        profile = UpdateProfileRequest(**data)
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))

    ok = update_driver_profile(cin, profile)
    if not ok:
        raise HTTPException(status_code=400, detail="Aucune donnée à modifier")

    return {"status": "success", "message": "Profil mis à jour"}

@router.post("/update-fcm-token")
async def route_update_fcm_token(request: Request):
    data = await request.json()
    cin       = data.get("cin")
    fcm_token = data.get("fcm_token")
    print(f">>> [FCM] cin reçu: '{cin}', token: {fcm_token[:20] if fcm_token else None}")

    if not cin or not fcm_token:
        raise HTTPException(status_code=400, detail="cin et fcm_token requis")

    try:
        result = update_fcm_token(cin, fcm_token)
        if result is None:
            raise HTTPException(status_code=404, detail=f"Driver {cin} introuvable")
        return {"success": True, "cin": cin}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail="Erreur serveur")

