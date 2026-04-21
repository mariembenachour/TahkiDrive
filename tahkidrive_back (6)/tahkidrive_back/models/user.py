from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class User(BaseModel):
    id: str
    createdat: Optional[datetime] = None
    display_name: Optional[str] = None
    email: Optional[str] = None
    enabled: Optional[bool] = None
    lastpasswordresetdate: Optional[datetime] = None
    username: Optional[str] = None
    codeQR: Optional[str] = None