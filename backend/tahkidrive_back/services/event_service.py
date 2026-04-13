from db import get_connection
from datetime import datetime, timedelta

def get_all_events(user_id: int):
    conn = get_connection()
    cursor = conn.cursor()

    events = []

    # -------------------------
    # 1. DOCUMENTS
    # -------------------------
    cursor.execute("""
        SELECT d.id, d.doc_type, d.begin_date, d.end_date, d.cost, d.reference_unique,
               p.name as provider_name, p.telephone, p.adresse,
               v.mark, v.model
        FROM document d
        JOIN vehicule v ON d.vehicule_id = v.id
        JOIN user_vehicule uv ON uv.vehicule_id = v.id
        LEFT JOIN provider p ON d.provider_id = p.id
        WHERE uv.user_id = %s
    """, (user_id,))
    
    docs = cursor.fetchall()
    for d in docs:
        doc = dict(d)
        doc['event_category'] = 'document'

        if doc.get('end_date'):
            end_date = doc['end_date'].date() if isinstance(doc['end_date'], datetime) else doc['end_date']
            doc['is_upcoming'] = end_date > datetime.now().date()
        else:
            doc['is_upcoming'] = False

        events.append(doc)

    # -------------------------
    # 2. MAINTENANCE (OIL CHANGE ONLY)
    # -------------------------
    cursor.execute("""
        SELECT m.id, m.maintenance_type, m.date_operation, m.cost, m.observation,
               m.vehicule_id, m.labor_cost, m.actual_repair_time, m.id_garage,
               v.mark, v.model,
               g.nom as garage_name, g.telephone, g.adresse
        FROM maintenance m
        JOIN vehicule v ON m.vehicule_id = v.id
        JOIN user_vehicule uv ON uv.vehicule_id = v.id
        LEFT JOIN garage g ON m.id_garage = g.id
        WHERE uv.user_id = %s AND LOWER(m.maintenance_type) LIKE '%%oil%%'
        ORDER BY m.date_operation DESC
    """, (user_id,))
    
    maints = cursor.fetchall()
    for m in maints:
        maint = dict(m)
        maint['event_category'] = 'maintenance'

        # upcoming pour oil change
        if maint.get('date_operation'):
            op_date = maint['date_operation'].date() if isinstance(maint['date_operation'], datetime) else maint['date_operation']
            next_oil_date = op_date + timedelta(days=180)
            maint['is_upcoming'] = next_oil_date > datetime.now().date()
            maint['next_oil_date'] = next_oil_date  # facultatif
        else:
            maint['is_upcoming'] = False
            maint['next_oil_date'] = None

        events.append(maint)

    conn.close()

    # -------------------------
    # Trier par date (documents: begin_date / oil change: next_oil_date)
    # -------------------------
    def get_sort_date(e):
        if e['event_category'] == 'document' and e.get('begin_date'):
            d = e['begin_date'].date() if isinstance(e['begin_date'], datetime) else e['begin_date']
            return d
        if e['event_category'] == 'maintenance' and e.get('date_operation'):
            d = e['date_operation'].date() if isinstance(e['date_operation'], datetime) else e['date_operation']
            return d + timedelta(days=180)  # pour trier par prochaine vidange
        return datetime.min.date()

    events.sort(key=get_sort_date, reverse=True)

    # -------------------------
    # Retour JSON
    # -------------------------
    return {
        "all_events": events,
 "upcoming_events": [
        {
            **e,
            "date_operation": e["next_oil_date"] if e.get("event_category") == "maintenance" else e.get("begin_date")
        }
        for e in events if e.get('is_upcoming')
    ] }