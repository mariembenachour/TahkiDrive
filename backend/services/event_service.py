# services/events_service.py

from db import get_connection
from datetime import datetime, timedelta
from models.event import Event, EventCreate, EventUpdate, OffenseCreate, OffenseUpdate
from models.compte_driver import CompteDriver
from models.sav import Sav


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
                       date_reparation, type_sav, vehicule_id, garage_id
                FROM sav
                WHERE vehicule_id = %s
                  AND type_sav = 'maintenance'
                  AND LOWER(maintenance_type) = 'oil change'
                ORDER BY date_reparation DESC
            """, (matricule,))

            for row in cursor.fetchall():
                # ✅ dict BD → modèle Sav
                sav = Sav(
                    id_sav           = row["id_sav"],
                    date_reparation  = row["date_reparation"],
                    vehicule_id      = row["vehicule_id"],
                    garage_id        = row["garage_id"],
                    type_sav         = row.get("type_sav"),
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