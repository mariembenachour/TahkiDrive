import os
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials
from dependencies import security
from services.auth_service import decode_token
from services import event_service

router  = APIRouter()
IS_PROD = os.getenv("ENV", "dev") == "prod"


def get_current_driver(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    if credentials:
        try:
            payload = decode_token(credentials.credentials)
            cin = payload.get("cin")
            if cin:
                return str(cin)
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")


@router.get("/api/events/pannes")
def get_panne_events(
    driver_id: str = Depends(get_current_driver),
    limit: int = 50,
    only_unnotified: bool = False,
):
    return event_service.get_panne_events(driver_id, limit, only_unnotified)


@router.get("/api/events/pannes/notified")
def get_notified_panne_events(
    driver_id: str = Depends(get_current_driver),
    limit: int = 50,
    today_only: bool = False,
):
    return event_service.get_notified_panne_events(driver_id, limit, today_only)


@router.get("/api/events/documents")
def get_document_events(driver_id: str = Depends(get_current_driver)):
    return event_service.get_document_events(driver_id)


@router.get("/api/events/unread-count")
def get_unread_events_count(driver_id: str = Depends(get_current_driver)):
    return event_service.get_unread_events_count(driver_id)


@router.post("/api/events/{event_id}/mark-notified")
def mark_event_as_notified(
    event_id: int,
    driver_id: str = Depends(get_current_driver),
):
    updated = event_service.mark_event_as_notified(event_id, driver_id)
    if not updated:
        raise HTTPException(status_code=404, detail="Event non trouvé")
    return {"success": True}


@router.get("/api/events/all")
def get_all_events(driver_id: str = Depends(get_current_driver)):
    return event_service.get_all_panne_events(driver_id)