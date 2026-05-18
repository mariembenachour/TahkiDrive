from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class AiDiagnostic(BaseModel):
    event_id: int                               # PK + FK → events.id
    driver_id: str                              # FK → compte_driver.cin
    code: int
    severity: str                               # enum: critical | warning | info
    created_at: datetime
    diagnosis: Optional[str] = None
    cause: Optional[str] = None
    action_required: Optional[str] = None
    estimated_risk: Optional[str] = None
    urgency_hours: Optional[int] = None
    is_resolved: Optional[bool] = None
    resolved_at: Optional[datetime] = None
    label: Optional[str] = None
    car_voice: Optional[str] = None