from fastapi import APIRouter, HTTPException, Depends
from services.driver_service import get_driver_by_cin
from dependencies import get_current_user

router = APIRouter()

@router.get("/driver/me")
def get_my_profile(user_id: str = Depends(get_current_user)):
    try:
        driver = get_driver_by_cin(user_id)
        if not driver:
            raise HTTPException(status_code=404, detail="Profil driver introuvable")
        return {"driver": dict(driver)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))