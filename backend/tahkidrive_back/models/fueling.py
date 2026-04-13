# models/fueling.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class Fueling(BaseModel):
    id: int
    cost_unit: Optional[float] = None
    number_payment: Optional[int] = None
    observation: Optional[str] = None
    quantity: Optional[float] = None
    payment_type: Optional[str] = None
    cost_total: Optional[float] = None
    date: Optional[datetime] = None
    num_cart_fuel: Optional[str] = None
    lieu: Optional[str] = None
    reference_unique: Optional[str] = None
    id_provider: Optional[int] = None
    id_vehicule: Optional[int] = None

class LastConsumption(BaseModel):
    fuel: Optional[float] = None
    date: Optional[datetime] = None

class FuelingResponse(BaseModel):
    id_vehicule: int
    id_device: int
    all_fuelings: List[Fueling]
    last_fueling: Optional[Fueling] = None
    last_consumption: Optional[LastConsumption] = None
    remaining_fuel: Optional[float] = None