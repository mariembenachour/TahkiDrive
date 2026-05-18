# controllers/chat_controller.py
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from typing import List, Optional

from services.auth_service import decode_token

router = APIRouter(prefix="/api/chat", tags=["chat"])
security = HTTPBearer()


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []


class ChatResponse(BaseModel):
    reply: str
    driver_id: str


def get_driver_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """Extrait le driver_id depuis le JWT token (même décodeur que auth_service)."""
    token = credentials.credentials.strip()
    try:
        payload = decode_token(token)

        driver_id = (
            payload.get("cin")
            or payload.get("sub")
            or payload.get("driver_id")
            or payload.get("id")
            or payload.get("user_id")
        )

        if not driver_id:
            print(f"[chat_controller] Payload reçu: {payload}")
            raise HTTPException(
                status_code=401,
                detail=f"Token invalide — champs disponibles: {list(payload.keys())}",
            )

        return str(driver_id)

    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token invalide: {e}")


@router.post("/message", response_model=ChatResponse)
async def send_message(
    body: ChatRequest,
    driver_id: str = Depends(get_driver_id),
):
    """Envoie un message à Aura et retourne la réponse."""
    from services.chat_service import chat_with_aura

    if not body.message or not body.message.strip():
        raise HTTPException(status_code=400, detail="Message vide")

    history = [{"role": m.role, "content": m.content} for m in (body.history or [])]

    reply = chat_with_aura(
        driver_id=driver_id,
        messages=history,
        user_message=body.message.strip(),
    )

    return ChatResponse(reply=reply, driver_id=driver_id)


@router.get("/health")
async def health():
    return {"status": "ok", "service": "aura-chat"}