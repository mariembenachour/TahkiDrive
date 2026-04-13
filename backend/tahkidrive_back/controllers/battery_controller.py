# controllers/battery_controller.py
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.battery_service import get_battery_maintenance
from models.battery import BatteryResponse  
import jwt

router = APIRouter()
security = HTTPBearer(auto_error=False)

SECRET_KEY = "ton_secret_key"
TEST_USER_ID = 6

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials is None:
        return TEST_USER_ID
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub") or payload.get("user_id")
        if user_id is None:
            return TEST_USER_ID
        return int(user_id)
    except Exception:
        return TEST_USER_ID

@router.get("/battery", response_model=BatteryResponse)
def get_battery(user_id: int = Depends(get_current_user)):
    data, error = get_battery_maintenance(user_id)
    if error:
        raise HTTPException(status_code=404, detail=error)
    return data