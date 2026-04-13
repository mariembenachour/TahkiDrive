# models/maintenance_model.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime  # 👈 datetime au lieu de date
from models.garage import Garage

class Maintenance(BaseModel):
    id: int
    maintenance_type: Optional[str] = None
    date_operation: Optional[datetime] = None  # 👈 datetime au lieu de date
    cost: Optional[float] = None
    labor_cost: Optional[float] = None
    observation: Optional[str] = None
    actual_repair_time: Optional[float] = None
    vehicule_id: Optional[int] = None
    garage: Optional[Garage] = None