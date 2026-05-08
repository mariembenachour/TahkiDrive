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
    get_device_by_serial, get_device_by_id,
    is_vehicule_already_linked,
    create_driver, link_vehicule_to_driver, update_driver_profile,
)
import os
from dependencies import get_current_user, security
from pydantic import BaseModel  # ← AJOUTE CETTE LIGNE

router = APIRouter(prefix="/auth", tags=["auth"])

IS_PROD = os.getenv("ENV", "dev") == "prod"

# ← AJOUTE CE MODÈLE PYDANTIC
class LoginRequest(BaseModel):
    email: str
    password: str

class AdminLoginRequest(BaseModel):
    email: str
    password: str

# ─── LOGIN DRIVER (CORRIGÉ) ─────────────────────────────────────────────

@router.post("/login/driver")
async def login_driver(login_data: LoginRequest):  # ← CHANGE ICI
    """Login driver avec email + password → retourne JWT full_access."""
    email = login_data.email.strip()
    password = login_data.password

    if not email or not password:
        raise HTTPException(status_code=400, detail="email et password requis")

    driver = get_driver_by_email(email)
    if not driver:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    pwd_ok = verify_password(password, driver["password"]) or (password == driver["password"])
    if not pwd_ok:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    if not driver["driver_authorized"]:
        raise HTTPException(status_code=403, detail="Compte en attente de validation admin")

    token = create_access_token(driver["cin"])
    return {
        "access_token": token,
        "token_type":   "bearer",
        "cin":          driver["cin"],
        "driver": {
            "cin":               driver["cin"],
            "first_name":        driver["first_name"],
            "last_name":         driver["last_name"],
            "email":             driver["email"],
            "language":          driver["language"],
            "driver_authorized": bool(driver["driver_authorized"]),
        },
    }


# ─── LOGIN ADMIN (CORRIGÉ) ─────────────────────────────────────────────

@router.post("/login/admin")
async def login_admin(login_data: AdminLoginRequest):  # ← CHANGE ICI
    """Login admin avec email + password → retourne JWT admin."""
    email = login_data.email.strip()
    password = login_data.password

    if not email or not password:
        raise HTTPException(status_code=400, detail="email et password requis")

    admin = get_admin_by_email(email)
    if not admin:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    pwd_ok = verify_password(password, admin["password"]) or (password == admin["password"])
    if not pwd_ok:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    token = create_admin_token(admin["cin"])
    return {
        "access_token": token,
        "token_type":   "bearer",
        "cin":          admin["cin"],
    }


# ─── SCAN QR + REGISTER DRIVER ─────────────────────────────────────────
@router.post("/scan-register")
async def scan_register(request: Request):
    """
    Le driver scanne le QR du boitier + le QR vendor.
    Crée un compte driver (PENDING) et retourne un setup_token 15 min.
    """
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

    # ── Validation des champs obligatoires ───────────────────────────────────
    if not cin or not email or not password:
        raise HTTPException(
            status_code=400,
            detail="cin, email et password requis"
        )

    # ── Vérification : CIN déjà enregistré ? ─────────────────────────────────
    if get_driver_by_cin(cin):
        raise HTTPException(
            status_code=409,
            detail="Ce CIN est déjà enregistré"
        )

    # ── Vérification : Email déjà enregistré ? ────────────────────────────────
    if get_driver_by_email(email):
        raise HTTPException(
            status_code=409,
            detail="Cet email est déjà utilisé"
        )

    # ── Parse QR Boitier ─────────────────────────────────────────────────────
    try:
        device_data = json.loads(device_qr_raw)
    except Exception:
        # Si c'est un simple serial (pas du JSON)
        device_data = {"serial": device_qr_raw}

    serial = device_data.get("serial", "").strip()
    if not serial:
        raise HTTPException(
            status_code=400,
            detail="QR boitier invalide : serial manquant"
        )

    device = get_device_by_serial(serial)
    if not device:
        raise HTTPException(
            status_code=404,
            detail=f"Boitier introuvable pour le serial : {serial}"
        )

    matricule = device.get("vehicule_id") or device.get("matricule", "")
    print("serial =", serial)
    print("device =", device)
    print("matricule envoyé =", repr(matricule))
    print("linked =", is_vehicule_already_linked(matricule))
    if matricule and is_vehicule_already_linked(matricule, exclude_cin=cin):
            return {
                "status": "already_linked",
                "message": "Ce véhicule est déjà associé à un compte"
            }

    # ── Parse QR Revendeur ───────────────────────────────────────────────────
    try:
        vendor_data = json.loads(vendor_qr_raw)
    except Exception:
        vendor_data = {"token": vendor_qr_raw}

    vendor_id  = vendor_data.get("vendor_id", "").strip()
    token_val  = vendor_data.get("token", "").strip()

    if not vendor_id or not token_val:
        raise HTTPException(
            status_code=400,
            detail="QR revendeur invalide : vendor_id ou token manquant"
        )

    vendor_token = get_vendor_token(vendor_id, token_val)
    if not vendor_token:
        raise HTTPException(
            status_code=403,
            detail="Token revendeur invalide ou expiré"
        )

    # ── Création du driver en base ────────────────────────────────────────────
    code_qr = device_qr_raw  # on stocke le QR brut comme référence
    create_driver(
        cin=cin,
        email=email,
        password=password,
        fcm_token=fcm_token,
        language=language,
        code_qr=code_qr,
    )

    # ── Lien véhicule → driver ────────────────────────────────────────────────
    if matricule:
        link_vehicule_to_driver(cin, matricule)

    # ── Décrémentation du token revendeur ─────────────────────────────────────
    decrement_vendor_token(vendor_token["id"])

    # ── Génération du setup_token (15 min) ────────────────────────────────────
    setup_token = create_setup_token(cin)

    return {
        "message":     "Compte créé. Complétez votre profil.",
        "setup_token": setup_token,
        "cin":         cin,
    }
# ─── SETUP PROFIL ─────────────────────────────────────────────────────

@router.patch("/setup-profile")
async def setup_profile(
    request: Request,
    cin: str = Depends(get_current_user),
):
    """Après scan QR, le driver complète son profil (setup_token 15 min)."""
    try:
        data = await request.json()
    except:
        raise HTTPException(status_code=400, detail="Body JSON invalide")

    required = ["first_name", "last_name", "telephone"]
    for field in required:
        if not data.get(field):
            raise HTTPException(status_code=400, detail=f"Champ manquant : {field}")

    update_driver_profile(cin, data)
    return {"message": "Profil soumis. En attente de validation admin.", "status": "pending"}


# ─── STATUS ───────────────────────────────────────────────────────────

@router.get("/status")
def check_status(cin: str = Depends(get_current_user)):
    driver = get_driver_by_cin(cin)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")

    if bool(driver["driver_authorized"]):
        return {
            "activated":    True,
            "access_token": create_access_token(cin),
            "cin":          cin,
        }
    return {"activated": False, "message": "En attente de validation admin"}


# ─── ME ───────────────────────────────────────────────────────────────

@router.get("/me")
def get_me(cin: str = Depends(get_current_user)):
    driver = get_driver_by_cin(cin)
    if not driver:
        raise HTTPException(status_code=404, detail="Driver introuvable")
    return {"driver": dict(driver)}
from fastapi import Body

@router.put("/update-profile")
async def update_profile(
    data: dict = Body(...),
    cin: str = Depends(get_current_user),
):
    """
    Driver connecté modifie ses infos.
    """

    if not data:
        raise HTTPException(status_code=400, detail="Body vide")

    ok = update_driver_profile(cin, data)

    if not ok:
        raise HTTPException(status_code=400, detail="Aucune donnée à modifier")

    return {
        "status": "success",
        "message": "Profil mis à jour"
    }