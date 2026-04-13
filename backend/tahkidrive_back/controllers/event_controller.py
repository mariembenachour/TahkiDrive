from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.event_service import get_all_events
 
import jwt
import os
 
router = APIRouter()
security = HTTPBearer(auto_error=False)
 
SECRET_KEY = os.getenv("SECRET_KEY", "ton_secret_key")
TEST_USER_ID = int(os.getenv("TEST_USER_ID", "6"))
IS_PROD = os.getenv("ENV", "dev") == "prod"
 
 
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials:
        try:
            payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
            user_id = payload.get("user_id")
            if user_id:
                return int(user_id)
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
 
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")
    else:
        return TEST_USER_ID
 
 
@router.get("/events")
def all_events(user_id: int = Depends(get_current_user)):
    try:
        data = get_all_events(user_id)
        return {"events": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
