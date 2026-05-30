from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import date
from services.event_service import (
    get_all_events, create_document, create_offense,
    update_document, update_offense, delete_event  # ← nouveaux imports
)
from dependencies import get_current_user

router = APIRouter()


class DocumentCreate(BaseModel):
    doc_type: str
    end_date: date


class OffenseCreate(BaseModel):
    offense_type: str
    offense_date: date
    paying: float

class DocumentUpdate(BaseModel):
    doc_type: str
    end_date: date

# Remplace l'ancien modèle
class OffenseUpdate(BaseModel):
    offense_type: str        # ← cette ligne manque
    offense_date: date
    paying: float

@router.get("/events")
def all_events(user_id: str = Depends(get_current_user)):
    try:
        data = get_all_events(user_id)
        return {"events": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/events/offense")
def add_offense(data: OffenseCreate, user_id: str = Depends(get_current_user)):
    try:
        from models.event import OffenseCreate as OffenseCreateModel
        offense_data = OffenseCreateModel(
            doc_type=     "OFFENSE",
            offense_type= data.offense_type,
            offense_date= data.offense_date,
            paying=       data.paying,
        )
        new_id = create_offense(driver_id=user_id, data=offense_data)
        return {"message": "Offense créée", "id": new_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/events/document")
def add_document(data: DocumentCreate, user_id: str = Depends(get_current_user)):
    try:
        from models.event import EventCreate
        doc_data = EventCreate(
            doc_type= data.doc_type,
            end_date= data.end_date,
        )
        new_id = create_document(driver_id=user_id, data=doc_data)
        return {"message": "Document créé", "id": new_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/events/document/{event_id}")
def edit_document(event_id: int, data: DocumentUpdate, user_id: str = Depends(get_current_user)):
    try:
        from models.event import EventUpdate
        doc_data = EventUpdate(doc_type=data.doc_type, end_date=data.end_date)
        ok = update_document(event_id, data=doc_data)
        if not ok:
            raise HTTPException(status_code=404, detail="Événement introuvable")
        return {"message": "Document mis à jour"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/events/offense/{event_id}")
def edit_offense(event_id: int, data: OffenseUpdate, user_id: str = Depends(get_current_user)):
    try:
        from models.event import OffenseUpdate as OffenseUpdateModel
        offense_data = OffenseUpdateModel(
            offense_type= data.offense_type,
            offense_date= data.offense_date,
            paying=       data.paying,
        )
        ok = update_offense(event_id, data=offense_data)
        if not ok:
            raise HTTPException(status_code=404, detail="Événement introuvable")
        return {"message": "Offense mise à jour"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))