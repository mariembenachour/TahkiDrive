# models/tire_model.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models.maintenance import Maintenance

class Tire(BaseModel):
    id: int
    date_buy: Optional[datetime] = None
    km_montage: Optional[int] = None
    mark: Optional[str] = None
    max_km: Optional[int] = None
    position: Optional[str] = None
    serie_number: Optional[str] = None
    balancing: Optional[int] = None
    calibration: Optional[int] = None
    parallelism: Optional[int] = None
    model: Optional[str] = None
    type_pneu: Optional[str] = None
    reference_unique: Optional[str] = None
    maintenance: Optional[Maintenance] = None

class TireResponse(BaseModel):
    last: Tire
    historique: List[Tire]