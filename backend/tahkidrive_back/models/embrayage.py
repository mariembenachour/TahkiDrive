# models/embrayage_model.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models.maintenance import Maintenance

class Embrayage(BaseModel):
    id: int
    date_buy: Optional[datetime] = None
    odometre: Optional[float] = None
    cost: Optional[float] = None
    mark: Optional[str] = None
    next_odometre: Optional[int] = None
    reference_unique: Optional[str] = None
    maintenance: Optional[Maintenance] = None

class EmbrayageResponse(BaseModel):
    last: Embrayage
    historique: List[Embrayage]