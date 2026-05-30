from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class NotifPreferences(BaseModel):
    pannes: Optional[bool] = True
    vitesse: Optional[bool] = True
    telephone: Optional[bool] = True
    distraction: Optional[bool] = True
    fatigue: Optional[bool] = True
    fume: Optional[bool] = True
    securite: Optional[bool] = True
    info: Optional[bool] = True
    daily_report: Optional[bool] = True
    daily_report_hour: Optional[int] = 20
 
 
class AlertThreshold(BaseModel):
    id: int                                     # PK
    driver_id: str                              # FK → compte_driver.cin (UNIQUE)
    max_speed_kmh: int
    max_car_temp: float
    max_engine_temp: int
    idle_max_minutes: int
    updated_at: datetime
    reminder_thresholds: Optional[List[int]] = None   # JSON
    notif_preferences: Optional[NotifPreferences] = None  # JSON
 
 
class NotifPreferencesUpdate(BaseModel):
    """Payload pour mettre à jour les préférences de notification."""
    notif_preferences: NotifPreferences
    reminder_thresholds: Optional[List[int]] = None