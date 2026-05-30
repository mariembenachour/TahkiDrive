from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class VendorToken(BaseModel):
    id: int                                     # PK
    vendor_id: str
    token: str                                  # UNIQUE
    uses_left: int
    expires_at: datetime
    created_at: Optional[datetime] = None
    created_by: Optional[str] = None
 