# models/garage_model.py
from pydantic import BaseModel
from typing import Optional

class Garage(BaseModel):
    id: int                                     # PK
    nom: str
    telephone: str
    adresse: str
    latitude: float
    longitude: float
    rating: Optional[float] = None
    heure_ouverture: Optional[str] = None
    heure_fermeture: Optional[str] = None
    conge: Optional[str] = None
    distance_km: Optional[float] = None        # calculé dynamiquement, pas en BD
 