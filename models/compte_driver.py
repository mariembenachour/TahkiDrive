from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class CompteDriver(BaseModel):
    cin: str
    email: str
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    telephone: Optional[str] = None
    driver_medically: Optional[bool] = None
    driving_training: Optional[bool] = None
    driving_safe: Optional[bool] = None
    driver_authorized: Optional[bool] = None
    codeQR: Optional[str] = None
    fcm_token: Optional[str] = None
    language: Optional[str] = None
    last_password_reset_date: Optional[datetime] = None
    vehicule_id: Optional[str] = None           # FK → vehicule.matricule
 
class CompteDriverPublic(BaseModel):
    """Version publique sans password ni password decrypted."""
    cin: str
    email: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    telephone: Optional[str] = None
    driver_medically: Optional[bool] = None
    driving_training: Optional[bool] = None
    driving_safe: Optional[bool] = None
    driver_authorized: Optional[bool] = None
    codeQR: Optional[str] = None
    fcm_token: Optional[str] = None
    language: Optional[str] = None
    last_password_reset_date: Optional[datetime] = None
    vehicule_id: Optional[str] = None
 