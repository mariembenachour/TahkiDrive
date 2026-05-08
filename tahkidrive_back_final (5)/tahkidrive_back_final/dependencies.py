# dependencies.py
import os
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from services.auth_service import decode_token, get_driver_by_cin

security = HTTPBearer(auto_error=False)
IS_PROD = os.getenv("ENV", "dev") == "prod"


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Retourne le CIN du driver connecté."""

    if not credentials:
        raise HTTPException(status_code=401, detail="Token requis")

    token = credentials.credentials.strip()  # supprime espaces parasites

    try:
        payload = decode_token(token)
        cin = payload.get("cin")
        if not cin:
            raise HTTPException(status_code=401, detail="CIN manquant dans le token")
        return str(cin)

    except ValueError as e:
        print(f"❌ Erreur décodage token: {e}")
        raise HTTPException(status_code=401, detail=str(e))

    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        raise HTTPException(status_code=401, detail="Token invalide")

