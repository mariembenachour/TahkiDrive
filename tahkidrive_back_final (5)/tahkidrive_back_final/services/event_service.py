# services/events_service.py
from db import get_connection
from datetime import datetime, timedelta


def safe_date(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    try:
        return datetime.fromisoformat(str(value)).date()
    except:
        return None


def create_document(driver_id: str, doc_type: str, end_date) -> int:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        cursor.execute(
            """
            INSERT INTO events (date, subtype, doc_type, end_date, driver_id, is_notified)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (now, 11, doc_type, end_date, driver_id, False),
        )
        conn.commit()
        return cursor.lastrowid
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def create_offense(
    driver_id: str,
    doc_type: str,
    offense_type: str,
    offense_date,
    paying: float,
) -> int:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        now = datetime.now()
        cursor.execute(
            """
            INSERT INTO events
                (date, subtype, doc_type, offense_type, offense_date, paying, driver_id, is_notified)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (now, 11, doc_type, offense_type, offense_date, paying, driver_id, False),
        )
        conn.commit()
        return cursor.lastrowid
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()

def update_document(event_id: int, doc_type: str, end_date) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE events
            SET doc_type = %s, end_date = %s
            WHERE id = %s
            """,
            (doc_type, end_date, event_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def update_offense(event_id: int, offense_type: str, offense_date, paying: float) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE events
            SET offense_type = %s, offense_date = %s, paying = %s
            WHERE id = %s
            """,
            (offense_type, offense_date, paying, event_id),
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
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # driver_id pour sécurité : un user ne peut supprimer que ses propres events
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
def get_all_events(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    events = []

    # ─── 1. DOCUMENTS ────────────────────────────────────────────────────────
    # driver_id = CIN (varchar) dans la table events
    cursor.execute("""
        SELECT
            id,
            doc_type,
            end_date,
            date,
            subtype,
            added_info,
            driver_id,
            is_notified,
            paying,
            offense_type,
            offense_date
        FROM events
        WHERE driver_id = %s
        AND doc_type <> ''
        ORDER BY end_date DESC
    """, (cin,))

    for d in cursor.fetchall():
        doc = dict(d)
        doc["event_category"] = "document"

        end = safe_date(doc.get("end_date"))
        doc["end_date"] = end
        doc["date"] = safe_date(doc.get("date"))
        doc["is_upcoming"] = end >= datetime.now().date() if end else False

        events.append(doc)

    # ─── 2. TOUTES LES MAINTENANCES (pas seulement Oil Change) ───────────────
    cursor.execute(
        "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (cin,)
    )
    driver_row = cursor.fetchone()
    matricule = driver_row["vehicule_id"] if driver_row else None

    if matricule:
        cursor.execute("""
            SELECT
                id_sav,
                maintenance_type,
                description,
                cost,
                date_reparation,
                type_sav,
                vehicule_id,
                garage_id
            FROM sav
            WHERE vehicule_id = %s
            AND type_sav = 'maintenance'
            AND LOWER(maintenance_type) = 'Oil Change'
            ORDER BY date_reparation DESC
            """, (matricule,))

        for m in cursor.fetchall():
            maint = dict(m)
            maint["event_category"] = "maintenance"

            date_rep = safe_date(maint.get("date_reparation"))
            date_pan = safe_date(maint.get("date_panne"))
            maint["date_reparation"] = date_rep
            maint["date_panne"] = date_pan

            maint["next_oil_km"] = None
            maint["estimated_next_date"] = None
            maint["is_upcoming"] = False
            maint["recent_done"] = date_rep is not None

            # ✅ Calcul upcoming uniquement pour Oil Change
            if str(maint.get("maintenance_type", "")).lower() == "oil change":
                odo = maint.get("odometre")
                interval_km = maint.get("interval_km")
                base_date = date_rep or date_pan

                if odo is not None and interval_km is not None and base_date:
                    try:
                        next_km = float(odo) + float(interval_km)
                        maint["next_oil_km"] = next_km

                        # Date estimée = base_date + 180 jours (simple)
                        next_date = base_date + timedelta(days=180)
                        maint["estimated_next_date"] = next_date

                        if next_date >= datetime.now().date():
                            maint["is_upcoming"] = True
                    except:
                        pass

            events.append(maint)

    conn.close()

    # ─── TRI GLOBAL ──────────────────────────────────────────────────────────
    def sort_key(e):
        if e["event_category"] == "document":
            return e.get("end_date") or datetime.min.date()

        return e.get("date_reparation") or e.get("date_panne") or datetime.min.date()
    events.sort(key=sort_key, reverse=True)
    # ─── UPCOMING ────────────────────────────────────────────────────────────
    upcoming = []
    for e in events:
        if not e.get("is_upcoming"):
            continue
        entry = dict(e)
        if e["event_category"] == "maintenance":
            entry["display_date"] = e.get("estimated_next_date")
        else:
            entry["display_date"] = e.get("end_date")
        upcoming.append(entry)

    # ─── RECENT ──────────────────────────────────────────────────────────────
    recent = []
    for e in events:
        if e["event_category"] == "document" and not e.get("is_upcoming"):
            recent.append(e)
        elif e["event_category"] == "maintenance" and e.get("date_reparation"):
            recent.append(e)

    return {
        "all_events": events,
        "upcoming_events": upcoming,
        "recent_events": recent,
    }