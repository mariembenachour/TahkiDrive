from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    cin: str
    scope: Optional[str] = None
 
 
class SuccessResponse(BaseModel):
    success: bool
    message: Optional[str] = None
 
 
class ErrorResponse(BaseModel):
    detail: str