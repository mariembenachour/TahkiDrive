from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.arch_service import calculate_odo_stats, get_fuel_stats, get_vehicule_id, _get_device_and_table
from db import get_connection
import jwt, os

router = APIRouter()
security = HTTPBearer(auto_error=False)

SECRET_KEY   = os.getenv("SECRET_KEY", "ton_secret_key")
TEST_USER_ID = int(os.getenv("TEST_USER_ID", "6"))
IS_PROD      = os.getenv("ENV", "dev") == "prod"


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
    return TEST_USER_ID


@router.get("/odo")
def odo_stats(
    vehicule_id: int = Query(None),
    user_id: int = Depends(get_current_user)
):
    data = calculate_odo_stats(user_id, vehicule_id)
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée ODO")
    return data


@router.get("/fuelings")
def fuel_stats(
    vehicule_id: int = Query(None),
    user_id: int = Depends(get_current_user)
):
    data = get_fuel_stats(user_id, vehicule_id)
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée carburant")
    return data


@router.get("/location")
def get_last_location(
    vehicule_id: int = Query(None),
    user_id: int = Depends(get_current_user)
):
    _, table_name = _get_device_and_table(user_id, vehicule_id)
    if not table_name:
        raise HTTPException(status_code=404, detail="Aucun device trouvé")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(f"""
                SELECT latitude, longitude
                FROM {table_name}
                ORDER BY date DESC
                LIMIT 1
            """)
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Aucune position trouvée")
            return {
                "latitude":  row["latitude"],
                "longitude": row["longitude"]
            }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()