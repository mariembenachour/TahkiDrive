from fastapi import APIRouter, HTTPException, Depends
from services.dashboard_driver import get_dashboard_data, get_weekly_stats
from dependencies import get_current_user

router = APIRouter()

@router.get("/driver/dashboard/stats")  # ← stats AVANT dashboard pour éviter conflit de route
def get_driver_stats(cin: str = Depends(get_current_user)):
    try:
        data = get_weekly_stats(cin)
        if "error" in data:
            raise HTTPException(status_code=404, detail=data["error"])
        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/driver/dashboard")
def get_driver_dashboard(cin: str = Depends(get_current_user)):
    try:
        data = get_dashboard_data(cin)
        if "error" in data:
            if data["error"] == "driver_not_found":
                raise HTTPException(status_code=404, detail="Conducteur introuvable")
            raise HTTPException(status_code=500, detail=data["error"])
        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))