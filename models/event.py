from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class Event(BaseModel):
    id: int                                     # PK
    date: datetime
    subtype: int
    added_info: Optional[int] = None
    driver_id: Optional[str] = None            # FK → compte_driver.cin
    doc_type: Optional[str] = None
    end_date: Optional[datetime] = None
    is_notified: Optional[bool] = None
    paying: Optional[float] = None
    offense_type: Optional[str] = None
    offense_date: Optional[datetime] = None
 
 
class EventCreate(BaseModel):
    """Payload pour créer un document."""
    doc_type: str
    end_date: datetime
 
 
class EventUpdate(BaseModel):
    """Payload pour modifier un document."""
    doc_type: Optional[str] = None
    end_date: Optional[datetime] = None
 
 
class OffenseCreate(BaseModel):
    """Payload pour créer une infraction."""
    doc_type: str
    offense_type: str
    offense_date: datetime
    paying: Optional[float] = None
 
 
class OffenseUpdate(BaseModel):
    """Payload pour modifier une infraction."""
    offense_type: Optional[str] = None
    offense_date: Optional[datetime] = None
    paying: Optional[float] = None
 