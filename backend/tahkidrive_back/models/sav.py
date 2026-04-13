from pydantic import BaseModel
from typing import Optional
from datetime import  datetime


class Sav(BaseModel):
    id: int
    date: Optional[datetime] = None
    vehicule_id: Optional[int] = None
    etat: Optional[str] = None
    type: Optional[str] = None
    description: Optional[str] = None
    id_garage: Optional[int] = None
    date_repare: Optional[datetime] = None
    id_sinistre: Optional[int] = None