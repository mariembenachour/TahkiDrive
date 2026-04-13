from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.sav_service import get_sav_by_user_id
from typing import Optional
import jwt
import os

router = APIRouter()
security = HTTPBearer(auto_error=False)

SECRET_KEY = os.getenv("SECRET_KEY", "ton_secret_key")
TEST_USER_ID = os.getenv("TEST_USER_ID", "6")
IS_PROD = os.getenv("ENV", "dev") == "prod"


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    if credentials:
        try:
            payload = jwt.decode(
                credentials.credentials,
                SECRET_KEY,
                algorithms=["HS256"]
            )

            user_id = payload.get("user_id")

            if user_id:
                return str(user_id)

        except Exception:
            raise HTTPException(
                status_code=401,
                detail="Token invalide"
            )

    if IS_PROD:
        raise HTTPException(
            status_code=401,
            detail="Non autorisé"
        )

    return TEST_USER_ID


@router.get("/sav/me")
def get_my_sav(
    category: Optional[str] = Query(
        None,
        description="accident ou panne"
    ),
    user_id: str = Depends(get_current_user)
):
    if category and category not in ["accident", "panne"]:
        raise HTTPException(
            status_code=400,
            detail="Catégorie invalide"
        )

    try:
        data = get_sav_by_user_id(user_id, category)

        return {
            "sav": data
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )