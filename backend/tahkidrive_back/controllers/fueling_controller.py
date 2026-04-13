# controllers/fueling_controller.py
from fastapi import APIRouter, HTTPException
from services.fueling_service import get_fuelings_by_device
from models.fueling import FuelingResponse  # 👈

router = APIRouter()

@router.get("/fuelings", response_model=FuelingResponse)  # 👈
def get_fuelings():
    data, error = get_fuelings_by_device()
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data