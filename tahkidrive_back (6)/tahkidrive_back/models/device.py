# models/device.py
from pydantic import BaseModel
from typing import Optional

class Device(BaseModel):
    id: int
    vehicule_id: int
    device_number: Optional[str]
    rawstream_id: Optional[str]
    stream_id: Optional[str]
    imei: Optional[str]
    icc: Optional[str]
    serial: Optional[str]