from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class Administrateur(BaseModel):
    cin: str
    email: str
    password: str
    last_password_reset_date: Optional[datetime] = None