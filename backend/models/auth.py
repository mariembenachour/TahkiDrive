from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class LoginRequest(BaseModel):
    email: str
    password: str
 
 
class AdminLoginRequest(BaseModel):
    email: str
    password: str
 
 
class RegisterRequest(BaseModel):
    cin: str
    email: str
    password: str
    fcm_token: Optional[str] = None
    language: Optional[str] = "fr"
    vendor_id: Optional[str] = None
    vendor_token: Optional[str] = None
 
 
class LinkVehiculeRequest(BaseModel):
    matricule: str
 
 
class UpdateProfileRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    telephone: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    fcm_token: Optional[str] = None
    language: Optional[str] = None
    driver_medically: Optional[bool] = None
    driving_training: Optional[bool] = None
    driving_safe: Optional[bool] = None
 
 

