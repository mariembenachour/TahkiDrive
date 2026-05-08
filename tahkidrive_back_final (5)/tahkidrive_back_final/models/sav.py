# models/sav_model.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class Sav(BaseModel):
    id_sav: int
    date_creation: Optional[datetime] = None
    etat: Optional[str] = None
    type_sav: Optional[str] = None          # ← nouveau champ pour type de SAV
    maintenance_type: Optional[str] = None  # ← pour type de maintenance
    description: Optional[str] = None
    cost: Optional[float] = None
    labor_cost: Optional[float] = None
    odometre: Optional[int] = None
    interval_km: Optional[int] = None
    date_operation: Optional[datetime] = None
    actual_repair_time: Optional[float] = None