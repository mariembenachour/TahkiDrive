import os
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials
from db import get_connection
from dependencies import security
from services.alert_messages import get_alert_info
from services.auth_service import decode_token

router   = APIRouter()
IS_PROD  = os.getenv("ENV", "dev") == "prod"

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
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT
                e.id,
                e.date,
                e.added_info  AS code,
                e.is_notified,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN compte_driver d  ON d.cin       = e.driver_id
            LEFT JOIN vehicule v  ON v.matricule  = d.vehicule_id
            WHERE e.driver_id = %s
              AND e.subtype   = 11
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
            event["title"], event["description"] = get_alert_info(event["code"])
            events.append(event)

        return {"events": events, "total": len(events)}
    finally:
        cursor.close()
        conn.close()


@router.get("/api/events/pannes/notified")
def get_notified_panne_events(
    driver_id: str = Depends(get_current_driver),
    limit: int = 50,
    today_only: bool = False,
):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT
                e.id,
                e.date,
                e.added_info  AS code,
                e.is_notified,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN compte_driver d  ON d.cin       = e.driver_id
            LEFT JOIN vehicule v  ON v.matricule  = d.vehicule_id
            WHERE e.driver_id = %s
              AND e.subtype   = 11
              AND e.added_info IS NOT NULL
              AND e.added_info != 0
              AND e.is_notified = TRUE
        """
        params = [driver_id]

        if today_only:
            query += " AND DATE(e.date) = CURDATE()"

        query += " ORDER BY e.date DESC LIMIT %s"
        params.append(limit)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        events = []
        for row in rows:
            event = dict(row)
            event["title"], event["description"] = get_alert_info(event["code"])
            event["date"] = str(event["date"])
            events.append(event)

        return {"events": events, "total": len(events)}
    finally:
        cursor.close()
        conn.close()


@router.get("/api/events/documents")
def get_document_events(driver_id: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                e.id,
                e.date,
                e.doc_type,
                e.end_date,
                e.is_notified
            FROM events e
            WHERE e.driver_id = %s
              AND e.doc_type IS NOT NULL
        """, (driver_id,))
        return {"events": [dict(r) for r in cursor.fetchall()]}
    finally:
        cursor.close()
        conn.close()


@router.get("/api/events/unread-count")
def get_unread_events_count(driver_id: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT COUNT(*) AS total
            FROM events
            WHERE driver_id = %s
              AND (is_notified = '0' OR is_notified IS FALSE OR is_notified IS NULL)
        """, (driver_id,))
        row = cursor.fetchone()
        return {"unread_count": row["total"] if row else 0}
    finally:
        cursor.close()
        conn.close()


@router.post("/api/events/{event_id}/mark-notified")
def mark_event_as_notified(
    event_id: int,
    driver_id: str = Depends(get_current_driver),
):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            UPDATE events SET is_notified = '1'
            WHERE id = %s AND driver_id = %s
        """, (event_id, driver_id))
        conn.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Event non trouvé")
        return {"success": True}
    finally:
        cursor.close()
        conn.close()


@router.get("/api/events/all")
def get_all_events(driver: str = Depends(get_current_driver)):
    conn   = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT
                e.id,
                e.date,
                e.added_info  AS code,
                e.is_notified,
                e.doc_type,
                e.end_date,
                v.mark,
                v.model,
                v.matricule
            FROM events e
            JOIN compte_driver d  ON d.cin       = e.driver_id
            LEFT JOIN vehicule v  ON v.matricule  = d.vehicule_id
            WHERE e.driver_id = %s
              AND e.subtype   = 11
            ORDER BY e.date DESC
        """, (driver,))

        rows   = cursor.fetchall()
        events = []

        for row in rows:
            event = dict(row)
            if event["doc_type"] is None:
                event["title"], event["description"] = get_alert_info(event["code"])
            else:
                event["title"]       = event["doc_type"]
                event["description"] = (
                    f"Expire le {event['end_date']}" if event.get("end_date")
                    else event["doc_type"]
                )
            for field in ["end_date", "date"]:
                if event.get(field):
                    event[field] = str(event[field])
            events.append(event)

        return {"events": events}
    finally:
        cursor.close()
        conn.close()