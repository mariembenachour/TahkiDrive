# models/distribution_model.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models.maintenance import Maintenance

class Distribution(BaseModel):
    id: int
    date_buy: Optional[datetime] = None
    odometre: Optional[float] = None
    cost: Optional[float] = None
    mark: Optional[str] = None
    next_odometre: Optional[float] = None
    reference_unique: Optional[str] = None
    type_piece: Optional[str] = None
    maintenance: Optional[Maintenance] = None

class DistributionResponse(BaseModel):
    last: Distribution
    historique: List[Distribution]