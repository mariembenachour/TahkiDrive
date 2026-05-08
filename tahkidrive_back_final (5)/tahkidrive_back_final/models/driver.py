from pydantic import BaseModel
from typing import Optional

class Driver(BaseModel):
    user_id: int
    cin: Optional[str] = None
    code: Optional[str] = None
    email: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    telephone: Optional[str] = None
    blood_group: Optional[str] = None
    rang_class: Optional[str] = None
    driver_medically: Optional[bool] = None
    driving_training: Optional[bool] = None
    driving_safe: Optional[bool] = None
    intervention_sites: Optional[str] = None
    driver_authorized: Optional[bool] = None
