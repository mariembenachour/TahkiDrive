from fastapi import APIRouter, HTTPException, Depends
from models.sav import SavCreate, SavUpdate
from services.sav_service import get_sav_by_driver, create_sav, update_sav, delete_sav, get_maintenance_types
from dependencies import get_current_user

router = APIRouter()


@router.get("/sav/maintenance-types")
def route_get_maintenance_types():
    return get_maintenance_types()


@router.get("/sav/me")
def get_my_sav(user_id: str = Depends(get_current_user)):
    try:
        return {"sav": get_sav_by_driver(user_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sav/me")
def route_create_sav(body: SavCreate, user_id: str = Depends(get_current_user)):
    try:
        new_id = create_sav(user_id, body)
        if new_id is None:
            raise HTTPException(status_code=404, detail="Véhicule introuvable")
        return {"id": new_id, "message": "SAV créé"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/sav/{id_sav}")
def route_update_sav(id_sav: int, body: SavUpdate, user_id: str = Depends(get_current_user)):
    try:
        ok = update_sav(id_sav, user_id, body)
        if not ok:
            raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
        return {"message": "SAV mis à jour"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sav/{id_sav}")
def route_delete_sav(id_sav: int, user_id: str = Depends(get_current_user)):
    try:
        ok = delete_sav(id_sav, user_id)
        if not ok:
            raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
        return {"message": "SAV supprimé"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))