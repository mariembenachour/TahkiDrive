from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime, date
class ChatMessage(BaseModel):
    role: str
    content: str
 
 
class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []
 
 
class ChatResponse(BaseModel):
    reply: str
    driver_id: str
 