# controllers/driver_controller.py
from fastapi import APIRouter, HTTPException, Depends
from services.driver_service import get_driver_by_cin
from models.compte_driver import CompteDriverPublic
from dependencies import get_current_user

router = APIRouter()


@router.get("/driver/me")
def get_my_profile(user_id: str = Depends(get_current_user)):
    """
    CORRECTION :
    Avant : return {"driver": dict(driver)} — le dict() était inutile si driver
            était déjà un dict brut de la BD.
    Maintenant : get_driver_by_cin retourne un CompteDriver (modèle Pydantic).
    On le convertit en CompteDriverPublic pour ne jamais exposer le password.
    """
    try:
        driver = get_driver_by_cin(user_id)
        if not driver:
            raise HTTPException(status_code=404, detail="Profil driver introuvable")

        # CompteDriver → CompteDriverPublic (sans password)
        # model_dump() convertit le modèle Pydantic en dict pour la réponse JSON
        public = CompteDriverPublic(**driver.model_dump())
        return {"driver": public.model_dump()}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))