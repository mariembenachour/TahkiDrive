# models/path.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class Path(BaseModel):
    id:                   int
    device_id:            Optional[int]    = None
    begin_path_time:      Optional[datetime] = None
    end_path_time:        Optional[datetime] = None
    begin_path_latitude:  Optional[float]  = None
    begin_path_longitude: Optional[float]  = None
    end_path_latitude:    Optional[float]  = None
    end_path_longitude:   Optional[float]  = None
    class Config:
        from_attributes = True