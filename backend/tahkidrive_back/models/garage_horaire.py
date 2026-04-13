# models/garage_horaire.py
from pydantic import BaseModel
from typing import Optional
from enum import Enum

class JourSemaine(str, Enum):
    LUNDI = "Lundi"
    MARDI = "Mardi"
    MERCREDI = "Mercredi"
    JEUDI = "Jeudi"
    VENDREDI = "Vendredi"
    SAMEDI = "Samedi"
    DIMANCHE = "Dimanche"

class GarageHoraire(BaseModel):
    id: int
    garage_id: int
    jour: JourSemaine
    heure_debut: str
    heure_fin: str
    est_ferme: bool = False

