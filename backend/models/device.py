# models/device.py
from pydantic import BaseModel
from typing import Optional

class Device(BaseModel):
    id: int                                     # PK bigint
    rawstream_id: int
    vehicule_id: Optional[str] = None          # FK → vehicule.matricule
    device_number: Optional[int] = None
    stream_id: Optional[str] = None
    imei: Optional[str] = None
    icc: Optional[str] = None
    serial: Optional[str] = None