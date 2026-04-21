# controllers/notification_controller.py
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from db import get_connection
import jwt
import os
from typing import Optional

router = APIRouter()
security = HTTPBearer(auto_error=False)
SECRET_KEY = os.getenv("SECRET_KEY", "ton_secret_key")
TEST_DRIVER_ID = int(os.getenv("TEST_DRIVER_ID", "6"))
IS_PROD = os.getenv("ENV", "dev") == "prod"

def get_current_driver(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials:
        try:
            payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
            driver_id = payload.get("driver_id")
            if driver_id:
                return int(driver_id)
        except Exception:
            raise HTTPException(status_code=401, detail="Token invalide")
    if IS_PROD:
        raise HTTPException(status_code=401, detail="Non autorisé")
    return TEST_DRIVER_ID


@router.get("/api/events/pannes")
def get_panne_events(
    driver_id: int = Depends(get_current_driver),
    limit: int = 50,
    only_unnotified: bool = False
):
    """
    Récupère les events de type panne pour un driver
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT 
                e.id,
                e.date,
                e.added_info as code,
                e.is_notified,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            LEFT JOIN driver_vehicule dv ON dv.driver_id = e.driver_id
            LEFT JOIN vehicule v ON v.id = dv.vehicule_id
            WHERE e.driver_id = %s
              AND e.type = 1
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
        """
        params = [driver_id]
        
        if only_unnotified:
            query += " AND (e.is_notified = '0' OR e.is_notified IS FALSE OR e.is_notified IS NULL)"
        
        query += " ORDER BY e.date DESC LIMIT %s"
        params.append(limit)
        
        cursor.execute(query, params)
        
        rows = cursor.fetchall()
        events = []
        for row in rows:
            event = dict(row)
            from services.notification_worker import PANNE_LABELS
            if event['code'] in PANNE_LABELS:
                event['title'], event['description'] = PANNE_LABELS[event['code']]
            events.append(event)
        
        return {"events": events, "total": len(events)}
    finally:
        conn.close()


@router.get("/api/events/documents")
def get_document_events(
    driver_id: int = Depends(get_current_driver),
):
    """
    Récupère les events de type document pour un driver
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT 
                e.id,
                e.date,
                e.doc_type,
                e.begin_date,
                e.end_date,
                e.is_notified
            FROM events e
            WHERE e.driver_id = %s
              AND e.type = 1
              AND e.doc_type IS NOT NULL
        """
        params = [driver_id]
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        return {"events": [dict(row) for row in rows]}
    finally:
        conn.close()


@router.get("/api/events/unread-count")
def get_unread_events_count(driver_id: int = Depends(get_current_driver)):
    """
    Compte les events non encore notifiés
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT 
                COUNT(*) as total
            FROM events
            WHERE driver_id = %s
              AND (is_notified = '0' OR is_notified IS FALSE OR is_notified IS NULL)
        """, (driver_id,))
        
        row = cursor.fetchone()
        return {"unread_count": row['total'] if row else 0}
    finally:
        conn.close()


@router.post("/api/events/{event_id}/mark-notified")
def mark_event_as_notified(
    event_id: int,
    driver_id: int = Depends(get_current_driver)
):
    """Marque un event comme notifié"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            UPDATE events 
            SET is_notified = '1'
            WHERE id = %s AND driver_id = %s
        """, (event_id, driver_id))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Event non trouvé")
        
        return {"success": True}
    finally:
        conn.close()


@router.get("/api/events/all")
def get_all_events(
    driver_id: int,
    driver: int = Depends(get_current_driver)
):
    """Récupère TOUS les events (pannes + documents) pour un driver"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT 
                e.id,
                e.date,
                e.added_info as code,
                e.is_notified,
                e.doc_type,
                e.begin_date,
                e.end_date,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            LEFT JOIN driver_vehicule dv ON dv.driver_id = e.driver_id
            LEFT JOIN vehicule v ON v.id = dv.vehicule_id
            WHERE e.driver_id = %s
              AND e.type = 1
            ORDER BY e.date DESC
        """, (driver_id,))
        
        rows = cursor.fetchall()
        events = []
        
        for row in rows:
            event = dict(row)
            
            if event['doc_type'] is None:
                # Panne
                from services.notification_worker import PANNE_LABELS
                code = event['code']
                if code in PANNE_LABELS:
                    event['title'], event['description'] = PANNE_LABELS[code]
                else:
                    event['title'] = 'Alerte'
                    event['description'] = 'Alerte véhicule'
            else:
                # Document
                event['title'] = event['doc_type']
                if event['begin_date'] and event['end_date']:
                    event['description'] = f"Du {event['begin_date']} au {event['end_date']}"
                else:
                    event['description'] = event['doc_type']
            
            # Convertir les dates
            if event['begin_date']:
                event['begin_date'] = str(event['begin_date'])
            if event['end_date']:
                event['end_date'] = str(event['end_date'])
            if event['date']:
                event['date'] = str(event['date'])
            
            events.append(event)
        
        return {"events": events}
    finally:
        conn.close()