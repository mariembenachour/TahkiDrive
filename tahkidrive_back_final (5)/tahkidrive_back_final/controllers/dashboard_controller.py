from fastapi import APIRouter, HTTPException, Depends
from services.dashboard_service import get_user_vehicule, get_last_temp, get_dashboard_data
from dependencies import get_current_user

router = APIRouter()

@router.get("/vehicules")
def dashboard_vehicules(user_id: str = Depends(get_current_user)):
    vehicule = get_user_vehicule(user_id)
    return {"vehicule": vehicule}

@router.get("/vehicule/temp")
def vehicule_last_temp(user_id: str = Depends(get_current_user)):
    temp = get_last_temp(user_id)
    return {"last_temp": temp if temp is not None else "Pas de donnée"}

@router.get("/dashboard/all")
def dashboard_all(user_id: str = Depends(get_current_user)):
    return get_dashboard_data(user_id)