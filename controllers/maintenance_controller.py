# controllers/maintenance_controller.py
from fastapi import APIRouter, HTTPException, Depends
from services.maintenance_service import get_maintenance_by_type
from dependencies import get_current_user

router = APIRouter()

# Aucun changement de logique — le controller n'a jamais touché la BD ici.
# get_maintenance_by_type retourne maintenant des dicts issus de Sav + Garage
# (via .model_dump() dans le service) — le controller n'a rien à changer.

@router.get("/maintenance/batterie")
def get_battery(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Batterie")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée batterie")
    return data


@router.get("/maintenance/frein")
def get_brake(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Frein")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée freins")
    return data


@router.get("/maintenance/vidange")
def get_oil_change(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Vidange")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée vidange")
    return data


@router.get("/maintenance/distribution")
def get_distribution(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Distribution")
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée distribution")
    return data


@router.get("/maintenance/pneu")
def get_tire(user_id: str = Depends(get_current_user)):
    data = get_maintenance_by_type(user_id, "Pneu")
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