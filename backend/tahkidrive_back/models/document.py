from pydantic import BaseModel
from typing import Optional, Dict

class Document(BaseModel):
    id: int
    doc_type: Optional[str]
    cost: Optional[float]
    begin_date: Optional[str]
    end_date: Optional[str]
    reference_unique: Optional[str]
    vehicule_id: int
    provider: Optional[Dict] = None  # provider info