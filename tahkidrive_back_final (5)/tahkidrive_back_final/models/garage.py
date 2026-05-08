# models/garage_model.py
from pydantic import BaseModel
from typing import Optional

class Garage(BaseModel):
    id: int
    nom: str
    telephone: Optional[str] = None
    adresse: Optional[str] = None
    rating: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    heure_ouverture: Optional[str] = None  # ex: "09:00"
    heure_fermeture: Optional[str] = None  # ex: "18:00"
    conge: Optional[str] = None  # ex: "Dimanche" ou "Samedi-Dimanche"
    distance_km: Optional[float] = None