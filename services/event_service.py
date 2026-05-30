# services/events_service.py

from db import get_connection
from datetime import datetime, timedelta
from models.event import Event, EventCreate, EventUpdate, OffenseCreate, OffenseUpdate
from models.compte_driver import CompteDriver
from models.sav import Sav
from services.alert_messages import get_alert_info  

def _safe_alert_info(code) -> tuple:
    try:
        return get_alert_info(int(code))
    except (TypeError, ValueError):
        return "Alerte inconnue", "Problème non identifié"

def safe_date(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    try:
        return datetime.fromisoformat(str(value)).date()
    except Exception:
        return None


def create_document(driver_id: str, data: EventCreate) -> int:
    """Crée un document. Reçoit un modèle EventCreate."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        cursor.execute(
            "INSERT INTO events (date, subtype, doc_type, end_date, driver_id, is_notified) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (now, 11, data.doc_type, data.end_date, driver_id, False),
        )
        conn.commit()
        return cursor.lastrowid
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def create_offense(driver_id: str, data: OffenseCreate) -> int:
    """Crée une infraction. Reçoit un modèle OffenseCreate."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        cursor.execute(
            "INSERT INTO events "
            "(date, subtype, doc_type, offense_type, offense_date, paying, driver_id, is_notified) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (now, 11, data.doc_type, data.offense_type, data.offense_date, data.paying, driver_id, False),
        )
        conn.commit()
        return cursor.lastrowid
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def update_document(event_id: int, data: EventUpdate) -> bool:
    """Modifie un document. Reçoit un modèle EventUpdate."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE events SET doc_type = %s, end_date = %s WHERE id = %s",
            (data.doc_type, data.end_date, event_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def update_offense(event_id: int, data: OffenseUpdate) -> bool:
    """Modifie une infraction. Reçoit un modèle OffenseUpdate."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE events SET offense_type = %s, offense_date = %s, paying = %s WHERE id = %s",
            (data.offense_type, data.offense_date, data.paying, event_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def delete_event(event_id: int, driver_id: str) -> bool:
    """Supprime un event. driver_id pour sécurité."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "DELETE FROM events WHERE id = %s AND driver_id = %s",
            (event_id, driver_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def get_all_events(cin: str) -> dict:
    conn = get_connection()
    cursor = conn.cursor()
    events = []

    try:
        # ── 1. DOCUMENTS ──────────────────────────────────────────────────────
        cursor.execute("""
            SELECT id, date, subtype, added_info, driver_id, is_notified,
                   paying, offense_type, offense_date, doc_type, end_date
            FROM events
            WHERE driver_id = %s AND doc_type <> ''
            ORDER BY end_date DESC
        """, (cin,))

        for row in cursor.fetchall():
            # ✅ dict BD → modèle Event
            ev = Event(
                id           = row["id"],
                date         = row["date"],
                subtype      = row["subtype"],
                added_info   = row.get("added_info"),
                driver_id    = row.get("driver_id"),
                doc_type     = row.get("doc_type"),
                end_date     = row.get("end_date"),
                is_notified  = bool(row.get("is_notified")),
                paying       = row.get("paying"),
                offense_type = row.get("offense_type"),
                offense_date = row.get("offense_date"),
            )
            doc = ev.dict()
            doc["event_category"] = "document"
            end = safe_date(ev.end_date)
            doc["end_date"] = end
            doc["date"]     = safe_date(ev.date)
            doc["is_upcoming"] = end >= datetime.now().date() if end else False
            events.append(doc)

        # ── 2. MAINTENANCES ───────────────────────────────────────────────────
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
        )
        driver_row = cursor.fetchone()
        if driver_row:
            driver = CompteDriver(**driver_row)   # ✅ dict BD → modèle CompteDriver
            matricule = driver.vehicule_id
        else:
            matricule = None

        if matricule:
           cursor.execute("""
                SELECT id_sav, maintenance_type, description, cost,
                    date_reparation, vehicule_id
                FROM sav
                WHERE vehicule_id = %s
                AND LOWER(maintenance_type) = 'vidange'
                ORDER BY date_reparation DESC
            """, (matricule,))

        for row in cursor.fetchall():
                sav = Sav(
                    id_sav           = row["id_sav"],
                    date_reparation  = row["date_reparation"],
                    vehicule_id      = row["vehicule_id"],
                    maintenance_type = row.get("maintenance_type"),
                    description      = row.get("description"),
                    cost             = float(row["cost"]) if row.get("cost") is not None else None,
                )
                maint = sav.dict()
                maint["event_category"] = "maintenance"

                date_rep = safe_date(sav.date_reparation)
                maint["date_reparation"]    = date_rep
                maint["date_panne"]         = None
                maint["next_oil_km"]        = None
                maint["estimated_next_date"] = None
                maint["is_upcoming"]        = False
                maint["recent_done"]        = date_rep is not None

                # Calcul upcoming pour Oil Change
                if str(sav.maintenance_type or "").lower() == "oil change":
                    base_date = date_rep
                    if base_date:
                        try:
                            next_date = base_date + timedelta(days=180)
                            maint["estimated_next_date"] = next_date
                            if next_date >= datetime.now().date():
                                maint["is_upcoming"] = True
                        except Exception:
                            pass

                events.append(maint)

    except Exception as e:
        print(f">>> [EVENTS] Erreur get_all_events: {e}")
    finally:
        cursor.close()
        conn.close()

    # ── TRI GLOBAL ────────────────────────────────────────────────────────────
    def sort_key(e):
        if e["event_category"] == "document":
            return e.get("end_date") or datetime.min.date()
        return e.get("date_reparation") or e.get("date_panne") or datetime.min.date()

    events.sort(key=sort_key, reverse=True)

    # ── UPCOMING ──────────────────────────────────────────────────────────────
    upcoming = []
    for e in events:
        if not e.get("is_upcoming"):
            continue
        entry = dict(e)
        entry["display_date"] = (
            e.get("estimated_next_date") if e["event_category"] == "maintenance"
            else e.get("end_date")
        )
        upcoming.append(entry)

    # ── RECENT ────────────────────────────────────────────────────────────────
    recent = []
    for e in events:
        if e["event_category"] == "document" and not e.get("is_upcoming"):
            recent.append(e)
        elif e["event_category"] == "maintenance" and e.get("date_reparation"):
            recent.append(e)

    return {
        "all_events":      events,
        "upcoming_events": upcoming,
        "recent_events":   recent,
    }
# ── PANNES ────────────────────────────────────────────────────────────────────

def get_panne_events(driver_id: str, limit: int = 50, only_unnotified: bool = False) -> dict:
    conn = get_connection()
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
            event["title"], event["description"] = _safe_alert_info(event["code"])
            events.append(event)

        return {"events": events, "total": len(events)}
    finally:
        cursor.close()
        conn.close()


def get_notified_panne_events(driver_id: str, limit: int = 50, today_only: bool = False) -> dict:
    conn = get_connection()
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
            event["title"], event["description"] = _safe_alert_info(event["code"])
            event["date"] = str(event["date"])
            events.append(event)

        return {"events": events, "total": len(events)}
    finally:
        cursor.close()
        conn.close()


def get_document_events(driver_id: str) -> dict:
    conn = get_connection()
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


def get_unread_events_count(driver_id: str) -> dict:
    conn = get_connection()
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


def mark_event_as_notified(event_id: int, driver_id: str) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            UPDATE events SET is_notified = '1'
            WHERE id = %s AND driver_id = %s
        """, (event_id, driver_id))
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def get_all_panne_events(driver_id: str) -> dict:
    conn = get_connection()
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
        """, (driver_id,))

        rows = cursor.fetchall()
        events = []

        for row in rows:
            event = dict(row)
            if event["doc_type"] is None:
                event["title"], event["description"] = get_alert_info(event["code"])
            else:
                event["title"] = event["doc_type"]
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