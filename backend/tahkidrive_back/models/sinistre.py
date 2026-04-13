from pydantic import BaseModel
from typing import Optional

class Sinistre(BaseModel):
    id: int
    place: Optional[str] = None
    refund: Optional[float] = None
    cabinet_expertise: Optional[str] = None
    reference_unique: Optional[str] = None

