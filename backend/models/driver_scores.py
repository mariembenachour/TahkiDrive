from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class DriverScore(BaseModel):
    id: int                                     # PK
    driver_id: str                              # FK → compte_driver.cin
    week_start: date
    global_score: int
    score_vitesse: int
    score_freinage: int
    score_vigilance: int
    score_fatigue: int
    score_securite: int
    computed_at: datetime
    ai_report: Optional[Any] = None   