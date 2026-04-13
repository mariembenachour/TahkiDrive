from pydantic import BaseModel
from typing import Optional

class Provider(BaseModel):
    id: int
    adresse: Optional[str]
    codetva: Optional[str]
    email: Optional[str]
    name: str
    telephone: Optional[str]
    type: Optional[str]