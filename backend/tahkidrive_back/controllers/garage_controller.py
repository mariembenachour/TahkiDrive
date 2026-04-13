# controllers/garage_controller.py
from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.garage_service import (
    get_all_garages,
    get_top_rated_garages,
    get_nearest_garages,
    get_nearest_garages_with_filters
)
from models.garage import Garage  # ← Changé ici (import depuis garage_model)
from typing import List, Optional
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


@router.get("/garages", response_model=List[Garage])
def get_all_garages_endpoint():
    """Récupère tous les garages avec leurs horaires"""
    try:
        garages = get_all_garages()
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/garages/top", response_model=List[Garage])
def get_top_garages_endpoint():
    """Récupère TOUS les garages triés par note avec leurs horaires"""
    try:
        garages = get_top_rated_garages()
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/garages/nearest", response_model=List[Garage])
def get_nearest_garages_endpoint(
    limit: int = Query(10, ge=1, le=50),
    lat: float = Query(..., description="Latitude de l'utilisateur"),
    lon: float = Query(..., description="Longitude de l'utilisateur"),
    min_rating: Optional[float] = Query(None, ge=0, le=5)
):
    """
    Récupère les garages les plus proches de l'utilisateur avec leurs horaires
    """
    try:
        if min_rating is not None and min_rating > 0:
            garages = get_nearest_garages_with_filters(limit, min_rating, lat, lon)
        else:
            garages = get_nearest_garages(limit, lat, lon)
        
        if not garages:
            raise HTTPException(status_code=404, detail="Aucun garage trouvé")
        
        return garages
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))