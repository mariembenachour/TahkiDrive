from fastapi import APIRouter, HTTPException, Depends
from services.maintenance_service import get_maintenance_by_type
from dependencies import get_current_user

router = APIRouter()

@router.get("/maintenance/battery")
def get_battery(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Battery")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée batterie")
    return data

@router.get("/maintenance/brake")
def get_brake(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Brake")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée freins")
    return data

@router.get("/maintenance/oil-change")
def get_oil_change(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Oil Change")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée vidange")
    return data

@router.get("/maintenance/distribution")
def get_distribution(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Distribution")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée distribution")
    return data

@router.get("/maintenance/tire")
def get_tire(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Tire")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée pneus")
    return data
@router.get("/maintenance/moteur")
def get_moteur(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Moteur")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée moteur")
    return data
@router.get("/maintenance/embrayage")
def get_embrayage(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Embrayage")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée embrayage")
    return data