# models/brake_model.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models.maintenance import Maintenance

class Brake(BaseModel):
    id: int
    disk: Optional[int] = None
    oil: Optional[str] = None
    position: Optional[str] = None
    pump: Optional[str] = None
    right_position: Optional[int] = None
    left_position: Optional[int] = None
    type_disk: Optional[str] = None
    type_left_position: Optional[str] = None
    type_right_position: Optional[str] = None
    odometre: Optional[float] = None
    next_odometre: Optional[float] = None
    reference_unique: Optional[str] = None
    maintenance: Optional[Maintenance] = None

class BrakeResponse(BaseModel):
    last: Brake
    historique: List[Brake]