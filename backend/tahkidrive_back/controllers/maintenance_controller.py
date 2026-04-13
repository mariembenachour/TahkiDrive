from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.maintenance_service import get_maintenance_by_type
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
            user_id = payload.get("user_id")
            if user_id:
                return int(user_id)
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")
    return TEST_USER_ID

@router.get("/maintenance/battery")
def get_battery(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Battery")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data

@router.get("/maintenance/brake")
def get_brake(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Brake")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data

@router.get("/maintenance/oil-change")
def get_oil_change(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Oil Change")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data

@router.get("/maintenance/distribution")
def get_distribution(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Distribution")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data

@router.get("/maintenance/tire")
def get_tire(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Tire")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data

@router.get("/maintenance/embrayage")
def get_embrayage(user_id: int = Depends(get_current_user)):
    data, error = get_maintenance_by_type(user_id, "Embrayage")
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data