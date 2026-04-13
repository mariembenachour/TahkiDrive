# models/garage_model.py
from pydantic import BaseModel
from typing import Optional

class Garage(BaseModel):
    id: int
    nom: Optional[str] = None
    telephone: Optional[str] = None
    adresse: Optional[str] = None
    rating: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None