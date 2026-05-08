# services/garage_service.py
from db import get_connection
import math
from datetime import datetime

def calculate_distance(lat1, lon1, lat2, lon2):
    """Calcule la distance en kilomètres entre deux points"""
    try:
        lat1 = float(lat1)
        lon1 = float(lon1)
        lat2 = float(lat2)
        lon2 = float(lon2)
        
        R = 6371  # Rayon de la Terre en km
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        # Formule de Haversine
        a = math.sin(delta_lat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return round(R * c, 2)
    except Exception as e:
        print(f"Erreur calculate_distance: {e}")
        return None

def get_all_garages():
    """Récupère tous les garages"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude, 
                   heure_ouverture, heure_fermeture, conge
            FROM garage
            ORDER BY nom
        """)
        rows = cursor.fetchall()
        result = []
        for row in rows:
            garage = dict(row)
            if garage.get("latitude"):
                garage["latitude"] = float(garage["latitude"])
            if garage.get("longitude"):
                garage["longitude"] = float(garage["longitude"])
            if garage.get("rating"):
                garage["rating"] = float(garage["rating"])
            result.append(garage)
        
        return result
    except Exception as e:
        print(f"Erreur get_all_garages: {e}")
        return []
    finally:
        conn.close()

def get_top_rated_garages():
    """Récupère TOUS les garages triés par note"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude,
                   heure_ouverture, heure_fermeture, conge
            FROM garage
            WHERE rating IS NOT NULL
            ORDER BY rating DESC
        """)
        rows = cursor.fetchall()
        result = []
        for row in rows:
            garage = dict(row)
            if garage.get("rating"):
                garage["rating"] = float(garage["rating"])
            if garage.get("latitude"):
                garage["latitude"] = float(garage["latitude"])
            if garage.get("longitude"):
                garage["longitude"] = float(garage["longitude"])
            result.append(garage)
        
        return result
    except Exception as e:
        print(f"Erreur get_top_rated_garages: {e}")
        return []
    finally:
        conn.close()

def get_nearest_garages(limit: int = 10, user_lat: float = None, user_lon: float = None):
    """Récupère les garages les plus proches"""
    try:
        if user_lat is None or user_lon is None:
            print("❌ Coordonnées utilisateur non fournies")
            return []
        
        all_garages = get_all_garages()
        
        result = []
        for garage in all_garages:
            if garage.get("latitude") and garage.get("longitude"):
                distance = calculate_distance(
                    user_lat, user_lon,
                    garage["latitude"], garage["longitude"]
                )
                if distance is not None:
                    garage["distance_km"] = distance
                    result.append(garage)
        
        result.sort(key=lambda x: x.get("distance_km", 9999))
        return result[:limit]
        
    except Exception as e:
        print(f"❌ Erreur get_nearest_garages: {e}")
        return []

def get_nearest_garages_with_filters(limit: int = 10, min_rating: float = None, user_lat: float = None, user_lon: float = None):
    """Récupère les garages les plus proches avec filtre sur la note"""
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
                FROM garage
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
            """
            params = []
            
            if min_rating is not None and min_rating > 0:
                query += " AND rating >= %s"
                params.append(min_rating)
            
            cursor.execute(query, params)
            garages = cursor.fetchall()
        finally:
            conn.close()
        
        result = []
        for garage in garages:
            garage_dict = dict(garage)
            if garage_dict.get("latitude"):
                garage_dict["latitude"] = float(garage_dict["latitude"])
            if garage_dict.get("longitude"):
                garage_dict["longitude"] = float(garage_dict["longitude"])
            if garage_dict.get("rating"):
                garage_dict["rating"] = float(garage_dict["rating"])
            
            distance = calculate_distance(
                user_lat, user_lon,
                garage_dict["latitude"], garage_dict["longitude"]
            )
            if distance is not None:
                garage_dict["distance_km"] = distance
                result.append(garage_dict)
        
        result.sort(key=lambda x: x.get("distance_km", 9999))
        return result[:limit]
        
    except Exception as e:
        print(f"Erreur get_nearest_garages_with_filters: {e}")
        return []

# ============ FONCTIONS POUR LE STATUT OUVERT/FERMÉ ============

def format_heure(heure):
    """Formate l'heure pour avoir toujours 2 chiffres pour les heures"""
    if not heure:
        return ""
    heure_str = str(heure).strip()
    if ':' in heure_str:
        heures = heure_str.split(':')[0]
        if len(heures) == 1:
            return '0' + heure_str
    return heure_str

def is_garage_open(garage):
    """Vérifie si le garage est ouvert actuellement"""
    heure_ouverture = garage.get('heure_ouverture')
    heure_fermeture = garage.get('heure_fermeture')
    conge = garage.get('conge')
    
    if not heure_ouverture or not heure_fermeture:
        return None
    
    now = datetime.now()
    # Convertir en nom de jour en français
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day = jours_fr.get(now.strftime("%A"), now.strftime("%A"))
    current_time = now.strftime("%H:%M")
    
    # Vérifier si aujourd'hui est un jour de congé
    if conge:
        jours_conge = [jour.strip() for jour in conge.split('-')]
        if current_day in jours_conge:
            return False
    
    ouverture = format_heure(heure_ouverture)
    fermeture = format_heure(heure_fermeture)
    
    return ouverture <= current_time <= fermeture

def get_open_status_text(heure_ouverture, heure_fermeture, conge):
    """Obtenir le message d'ouverture/fermeture"""
    if not heure_ouverture or not heure_fermeture:
        return "Horaires non disponibles"
    
    now = datetime.now()
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day = jours_fr.get(now.strftime("%A"), now.strftime("%A"))
    current_time = now.strftime("%H:%M")
    
    # Vérifier les congés
    if conge:
        jours_conge = [jour.strip() for jour in conge.split('-')]
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

def get_open_status_color(heure_ouverture, heure_fermeture, conge):
    """Obtenir la couleur du statut"""
    if not heure_ouverture or not heure_fermeture:
        return "grey"
    
    is_open = is_garage_open({
        'heure_ouverture': heure_ouverture,
        'heure_fermeture': heure_fermeture,
        'conge': conge
    })
    return "green" if is_open else "red"

def get_today_hours(heure_ouverture, heure_fermeture, conge):
    """Obtenir les horaires du jour"""
    if not heure_ouverture or not heure_fermeture:
        return ""
    
    now = datetime.now()
    jours_fr = {
        "Monday": "Lundi", "Tuesday": "Mardi", "Wednesday": "Mercredi",
        "Thursday": "Jeudi", "Friday": "Vendredi", "Saturday": "Samedi", "Sunday": "Dimanche"
    }
    current_day = jours_fr.get(now.strftime("%A"), now.strftime("%A"))
    
    # Vérifier les congés
    if conge:
        jours_conge = [jour.strip() for jour in conge.split('-')]
        if current_day in jours_conge:
            return "Fermé aujourd'hui"
    
    ouverture = format_heure(heure_ouverture)
    fermeture = format_heure(heure_fermeture)
    return f"{ouverture} - {fermeture}"