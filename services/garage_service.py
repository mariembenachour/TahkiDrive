# services/garage_service.py

import math
from datetime import datetime
from db import get_connection
from models.garage import Garage


def calculate_distance(lat1, lon1, lat2, lon2):
    """Calcule la distance en kilomètres entre deux points (Haversine)."""
    try:
        R = 6371
        lat1_rad = math.radians(float(lat1))
        lat2_rad = math.radians(float(lat2))
        delta_lat = math.radians(float(lat2) - float(lat1))
        delta_lon = math.radians(float(lon2) - float(lon1))
        a = math.sin(delta_lat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return round(R * c, 2)
    except Exception as e:
        print(f"Erreur calculate_distance: {e}")
        return None


def _row_to_garage(row: dict) -> Garage:
    """Convertit une ligne BD en modèle Garage."""
    return Garage(
        id              = row["id"],
        nom             = row["nom"],
        telephone       = row["telephone"],
        adresse         = row["adresse"],
        latitude        = float(row["latitude"]),
        longitude       = float(row["longitude"]),
        rating          = float(row["rating"]) if row.get("rating") is not None else None,
        heure_ouverture = row.get("heure_ouverture"),
        heure_fermeture = row.get("heure_fermeture"),
        conge           = row.get("conge"),
        distance_km     = row.get("distance_km"),
    )


def get_all_garages() -> list[dict]:
    """Récupère tous les garages."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude,
                   heure_ouverture, heure_fermeture, conge
            FROM garage ORDER BY nom
        """)
        rows = cursor.fetchall()
        result = []
        for row in rows:
            try:
                garage = _row_to_garage(row)   # ✅ dict BD → modèle Garage
                result.append(garage.dict())
            except Exception as e:
                print(f"Erreur conversion garage {row.get('id')}: {e}")
        return result
    except Exception as e:
        print(f"Erreur get_all_garages: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def get_top_rated_garages() -> list[dict]:
    """Récupère tous les garages triés par note."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude,
                   heure_ouverture, heure_fermeture, conge
            FROM garage WHERE rating IS NOT NULL
            ORDER BY rating DESC
        """)
        rows = cursor.fetchall()
        result = []
        for row in rows:
            try:
                garage = _row_to_garage(row)   # ✅ dict BD → modèle Garage
                result.append(garage.dict())
            except Exception as e:
                print(f"Erreur conversion garage {row.get('id')}: {e}")
        return result
    except Exception as e:
        print(f"Erreur get_top_rated_garages: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


def get_nearest_garages(limit: int = 10, user_lat: float = None, user_lon: float = None) -> list[dict]:
    """Récupère les garages les plus proches."""
    try:
        if user_lat is None or user_lon is None:
            print("❌ Coordonnées utilisateur non fournies")
            return []

        all_garages = get_all_garages()
        result = []
        for g in all_garages:
            if g.get("latitude") and g.get("longitude"):
                distance = calculate_distance(user_lat, user_lon, g["latitude"], g["longitude"])
                if distance is not None:
                    g["distance_km"] = distance
                    result.append(g)

        result.sort(key=lambda x: x.get("distance_km", 9999))
        return result[:limit]
    except Exception as e:
        print(f"❌ Erreur get_nearest_garages: {e}")
        return []


def get_nearest_garages_with_filters(limit: int = 10, min_rating: float = None,
                                     user_lat: float = None, user_lon: float = None) -> list[dict]:
    """Récupère les garages les plus proches avec filtre sur la note."""
    try:
        if user_lat is None or user_lon is None:
            print("❌ Coordonnées utilisateur non fournies")
            return []

        conn = get_connection()
        cursor = conn.cursor()
        try:
            query = """
                SELECT id, nom, telephone, adresse, rating, latitude, longitude,
                       heure_ouverture, heure_fermeture, conge
                FROM garage WHERE latitude IS NOT NULL AND longitude IS NOT NULL
            """
            params = []
            if min_rating is not None and min_rating > 0:
                query += " AND rating >= %s"
                params.append(min_rating)
            cursor.execute(query, params)
            rows = cursor.fetchall()
        finally:
            cursor.close()
            conn.close()

        result = []
        for row in rows:
            try:
                garage = _row_to_garage(row)   # ✅ dict BD → modèle Garage
                g = garage.dict()
                distance = calculate_distance(user_lat, user_lon, g["latitude"], g["longitude"])
                if distance is not None:
                    g["distance_km"] = distance
                    result.append(g)
            except Exception as e:
                print(f"Erreur conversion garage: {e}")

        result.sort(key=lambda x: x.get("distance_km", 9999))
        return result[:limit]
    except Exception as e:
        print(f"Erreur get_nearest_garages_with_filters: {e}")
        return []


# ── Statut ouvert / fermé ─────────────────────────────────────────────────────

def format_heure(heure):
    if not heure:
        return ""
    heure_str = str(heure).strip()
    if ':' in heure_str:
        heures = heure_str.split(':')[0]
        if len(heures) == 1:
            return '0' + heure_str
    return heure_str


def is_garage_open(garage: dict):
    heure_ouverture = garage.get('heure_ouverture')
    heure_fermeture = garage.get('heure_fermeture')
    conge           = garage.get('conge')

    if not heure_ouverture or not heure_fermeture:
        return None

    now = datetime.now()
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day  = jours_fr.get(now.strftime("%A"), now.strftime("%A"))
    current_time = now.strftime("%H:%M")

    if conge:
        jours_conge = [j.strip() for j in conge.split('-')]
        if current_day in jours_conge:
            return False

    ouverture = format_heure(heure_ouverture)
    fermeture = format_heure(heure_fermeture)
    return ouverture <= current_time <= fermeture


def get_open_status_text(heure_ouverture, heure_fermeture, conge) -> str:
    if not heure_ouverture or not heure_fermeture:
        return "Horaires non disponibles"

    now = datetime.now()
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day  = jours_fr.get(now.strftime("%A"), now.strftime("%A"))
    current_time = now.strftime("%H:%M")

    if conge:
        jours_conge = [j.strip() for j in conge.split('-')]
        if current_day in jours_conge:
            return "Fermé aujourd'hui"

    ouverture = format_heure(heure_ouverture)
    fermeture = format_heure(heure_fermeture)

    if ouverture <= current_time <= fermeture:
        return f"Ouvert • Ferme à {fermeture}"
    elif current_time < ouverture:
        return f"Fermé • Ouvre à {ouverture}"
    else:
        return "Fermé"


def get_open_status_color(heure_ouverture, heure_fermeture, conge) -> str:
    if not heure_ouverture or not heure_fermeture:
        return "grey"
    is_open = is_garage_open({
        'heure_ouverture': heure_ouverture,
        'heure_fermeture': heure_fermeture,
        'conge': conge,
    })
    return "green" if is_open else "red"


def get_today_hours(heure_ouverture, heure_fermeture, conge) -> str:
    if not heure_ouverture or not heure_fermeture:
        return ""

    now = datetime.now()
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day = jours_fr.get(now.strftime("%A"), now.strftime("%A"))

    if conge:
        jours_conge = [j.strip() for j in conge.split('-')]
        if current_day in jours_conge:
            return "Fermé aujourd'hui"

    ouverture = format_heure(heure_ouverture)
    fermeture = format_heure(heure_fermeture)
    return f"{ouverture} - {fermeture}"