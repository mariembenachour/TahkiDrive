from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.dashboard_service import (
    get_user_vehicules,
    get_last_temp,
    get_dashboard_data,
)
import jwt
import os

router = APIRouter()
security = HTTPBearer(auto_error=False)

SECRET_KEY = os.getenv("SECRET_KEY", "ton_secret_key")
TEST_USER_ID = int(os.getenv("TEST_USER_ID", "6"))
IS_PROD = os.getenv("ENV", "dev") == "prod"


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials:
        try:
            payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
            return int(payload.get("user_id"))
        except:
            raise HTTPException(status_code=401, detail="Token invalide")

    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")

    return TEST_USER_ID


# =========================
# VEHICULES
# =========================
@router.get("/vehicules")
def dashboard_vehicules(user_id: int = Depends(get_current_user)):
    return {"vehicules": get_user_vehicules(user_id)}


# =========================
# TEMP
# =========================
@router.get("/vehicule/temp")
def vehicule_last_temp(
    vehicule_id: int = Query(None),
    user_id: int = Depends(get_current_user)
):
    temp = get_last_temp(user_id, vehicule_id)
    return {"last_temp": temp if temp else "Pas de donnée"}


# =========================
# DASHBOARD GLOBAL
# =========================
@router.get("/dashboard/all")
def dashboard_all(
    vehicule_id: int = Query(None),
    user_id: int = Depends(get_current_user)
):
    return get_dashboard_data(user_id, vehicule_id)