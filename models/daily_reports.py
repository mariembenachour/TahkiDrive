from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class DailyReport(BaseModel):
    id: int                                     # PK
    driver_id: str                              # FK → compte_driver.cin
    report_date: date
    report_json: str                            # JSON stocké en text
    created_at: datetime
    score_today: Optional[int] = None