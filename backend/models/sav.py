# models/sav_model.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
class Sav(BaseModel):
    id_sav: int                                 # PK
    date_reparation: datetime                   # PK
    vehicule_id: str                            # PK + FK → vehicule.matricule
    garage_id: int                              # PK + FK → garage.id
    type_sav: Optional[str] = None             # 'maintenance' | 'accident'
    maintenance_type: Optional[str] = None
    description: Optional[str] = None
    cost: Optional[float] = None
 
 
class SavCreate(BaseModel):
    """Payload pour créer un SAV."""
    type_sav: str
    date_reparation: datetime
    maintenance_type: Optional[str] = None
    description: Optional[str] = None
    cost: Optional[float] = None
    garage_id: Optional[int] = None
 
 
class SavUpdate(BaseModel):
    """Payload pour modifier un SAV."""
    type_sav: Optional[str] = None
    maintenance_type: Optional[str] = None
    description: Optional[str] = None
    cost: Optional[float] = None
    date_reparation: Optional[datetime] = None
    garage_id: Optional[int] = None