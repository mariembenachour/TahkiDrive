from pydantic import BaseModel
from typing import Optional, List

class NotifPreferences(BaseModel):
    pannes:      Optional[bool] = True
    vitesse:     Optional[bool] = True
    telephone:   Optional[bool] = True
    distraction: Optional[bool] = True
    fatigue:     Optional[bool] = True
    fume:        Optional[bool] = True

DEFAULT_REMINDER_THRESHOLDS = [1800, 3600, 86400, 259200, 604800, 1209600]

class NotifPreferencesUpdate(BaseModel):
    notif_preferences:   NotifPreferences
    reminder_thresholds: Optional[List[int]] = None  # None = pas envoyé, [] = vide voulu
