# models/battery_model.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models.maintenance import Maintenance

class Battery(BaseModel):
    id: int
    mark: Optional[str] = None
    voltage: Optional[float] = None
    amperage: Optional[float] = None
    type_battery: Optional[str] = None
    serie_number: Optional[str] = None
    expiration_date: Optional[datetime] = None
    odometre: Optional[float] = None
    observations: Optional[str] = None
    prix_htva: Optional[float] = None
    prix_tva: Optional[float] = None
    maintenance: Optional[Maintenance] = None

class BatteryResponse(BaseModel):
    last: Battery
    historique: List[Battery]