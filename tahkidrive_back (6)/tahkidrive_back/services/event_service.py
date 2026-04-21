from db import get_connection
from datetime import datetime, timedelta


def get_all_events(driver_id: int):
    conn = get_connection()
    cursor = conn.cursor()

    events = []

    # =====================================
    # 1. DOCUMENTS => TABLE event
    # =====================================
    cursor.execute("""
        SELECT
            id,
            doc_type,
            begin_date,
            end_date,
            date,
            type,
            subtype,
            added_info,
            driver_id
        FROM events
        WHERE driver_id = %s
          AND doc_type IS NOT NULL
        ORDER BY begin_date DESC
    """, (driver_id,))

    docs = cursor.fetchall()

    for d in docs:
        doc = dict(d)
        doc["event_category"] = "document"

        if doc.get("end_date"):
            end_date = doc["end_date"].date() if isinstance(doc["end_date"], datetime) else doc["end_date"]
            doc["is_upcoming"] = end_date >= datetime.now().date()
        else:
            doc["is_upcoming"] = False

        events.append(doc)

    # =====================================
    # 2. MAINTENANCE => TABLE sav
    # =====================================
    cursor.execute("""
        SELECT
            id_sav,
            maintenance_type,
            description,
            cost,
            labor_cost,
            odometre,
            interval_km,
            date_operation,
            actual_repair_time,
            etat,
            type_sav
        FROM sav
        WHERE type_sav = 'maintenance'
          AND maintenance_type LIKE '%Oil%'
        ORDER BY date_operation DESC
    """)

    maints = cursor.fetchall()

    for m in maints:
        maint = dict(m)
        maint["event_category"] = "maintenance"

        if maint.get("date_operation"):
            op_date = maint["date_operation"].date() if isinstance(maint["date_operation"], datetime) else maint["date_operation"]

            next_oil_date = op_date + timedelta(days=180)

            maint["next_oil_date"] = next_oil_date
            maint["is_upcoming"] = next_oil_date >= datetime.now().date()
        else:
            maint["next_oil_date"] = None
            maint["is_upcoming"] = False

        events.append(maint)

    conn.close()

    # =====================================
    # TRI
    # =====================================
    def get_sort_date(e):

        if e["event_category"] == "document":
            if e.get("begin_date"):
                d = e["begin_date"]
                return d.date() if isinstance(d, datetime) else d

        if e["event_category"] == "maintenance":
            if e.get("next_oil_date"):
                return e["next_oil_date"]

        return datetime.min.date()

    events.sort(key=get_sort_date, reverse=True)

    # =====================================
    # RETURN
    # =====================================
    return {
        "all_events": events,

        "upcoming_events": [
            {
                **e,
                "display_date":
                    e["next_oil_date"]
                    if e["event_category"] == "maintenance"
                    else e.get("end_date")
            }
            for e in events
            if e.get("is_upcoming")
        ]
    }