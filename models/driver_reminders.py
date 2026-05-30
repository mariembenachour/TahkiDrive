from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class DriverReminder(BaseModel):
    id: int                                     # PK
    driver_id: str                              # FK → compte_driver.cin
    title: str
    remind_at: datetime
    is_sent: bool
    created_at: datetime
    description: Optional[str] = None
    vehicule_id: Optional[int] = None
    repeat_days: Optional[int] = None
 
 
class DriverReminderCreate(BaseModel):
    """Payload pour créer un rappel."""
    title: str
    remind_at: datetime
    description: Optional[str] = None
    repeat_days: Optional[int] = None
 
 
class DriverReminderUpdate(BaseModel):
    """Payload pour modifier un rappel."""
    title: Optional[str] = None
    remind_at: Optional[datetime] = None
    description: Optional[str] = None
    repeat_days: Optional[int] = None