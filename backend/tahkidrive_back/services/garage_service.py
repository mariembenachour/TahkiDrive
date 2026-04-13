# services/garage_service.py
from db import get_connection
import math
from datetime import datetime

# Mapping des jours
NUM_TO_JOUR = {
    0: "Lundi",
    1: "Mardi",
    2: "Mercredi",
    3: "Jeudi",
    4: "Vendredi",
    5: "Samedi",
    6: "Dimanche"
}

def calculate_distance(lat1, lon1, lat2, lon2):
    """Calcule la distance en kilomètres entre deux points"""
    try:
        lat1 = float(lat1)
        lon1 = float(lon1)
        lat2 = float(lat2)
        lon2 = float(lon2)
        
        R = 6371
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = math.sin(delta_lat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return round(R * c, 2)
    except Exception as e:
        print(f"Erreur calculate_distance: {e}")
        return None


def get_horaires_by_garage_id(garage_id: int):
    """Récupère les horaires d'un garage"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, idgarage, jour, heure_debut, heure_fin
            FROM garage_horaire
            WHERE idgarage = %s
            ORDER BY FIELD(jour, 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche')
        """, (garage_id,))
        rows = cursor.fetchall()
        
        result = []
        for row in rows:
            horaire = dict(row)
            horaire['garage_id'] = horaire['idgarage']
            horaire['heure_ouverture'] = horaire['heure_debut']
            horaire['heure_fermeture'] = horaire['heure_fin']
            horaire['est_ferme'] = False
            result.append(horaire)
        return result
    except Exception as e:
        print(f"Erreur get_horaires_by_garage_id: {e}")
        return []
    finally:
        conn.close()


def enrichir_garages_avec_horaires(garages):
    """Ajoute les horaires à chaque garage"""
    for garage in garages:
        garage['horaires'] = get_horaires_by_garage_id(garage['id'])
    return garages


def get_all_garages():
    """Récupère tous les garages avec leurs horaires"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude
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
        
        result = enrichir_garages_avec_horaires(result)
        return result
    except Exception as e:
        print(f"Erreur get_all_garages: {e}")
        return []
    finally:
        conn.close()


def get_top_rated_garages():
    """Récupère TOUS les garages triés par note avec leurs horaires"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT id, nom, telephone, adresse, rating, latitude, longitude
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
        
        result = enrichir_garages_avec_horaires(result)
        return result
    except Exception as e:
        print(f"Erreur get_top_rated_garages: {e}")
        return []
    finally:
        conn.close()


def get_nearest_garages(limit: int = 10, user_lat: float = None, user_lon: float = None):
    """Récupère les garages les plus proches avec leurs horaires"""
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
    """Récupère les garages les plus proches avec filtre sur la note et leurs horaires"""
    try:
        if user_lat is None or user_lon is None:
            print("❌ Coordonnées utilisateur non fournies")
            return []
        
        conn = get_connection()
        cursor = conn.cursor()
        try:
            query = """
                SELECT id, nom, telephone, adresse, rating, latitude, longitude
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
                garage_dict['horaires'] = get_horaires_by_garage_id(garage_dict['id'])
                result.append(garage_dict)
        
        result.sort(key=lambda x: x.get("distance_km", 9999))
        return result[:limit]
        
    except Exception as e:
        print(f"Erreur get_nearest_garages_with_filters: {e}")
        return []


# ============ FONCTIONS POUR LE STATUT OUVERT/FERMÉ ============

def is_garage_open(garage):
    """Vérifie si le garage est ouvert actuellement"""
    if 'horaires' not in garage or not garage['horaires']:
        return None
    
    now = datetime.now()
    current_day = NUM_TO_JOUR[now.weekday()]
    current_time = now.strftime("%H:%M")
    
    for horaire in garage['horaires']:
        if horaire['jour'] == current_day:
            if horaire.get('est_ferme', False):
                return False
            
            ouverture = horaire['heure_debut']
            fermeture = horaire['heure_fin']
            
            # Formater les heures avec zéro devant (8:00 -> 08:00)
            if len(ouverture.split(':')[0]) == 1:
                ouverture = '0' + ouverture
            if len(fermeture.split(':')[0]) == 1:
                fermeture = '0' + fermeture
            
            return ouverture <= current_time <= fermeture
    
    return False


def get_open_status_text(horaires):
    """Obtenir le message d'ouverture/fermeture"""
    if not horaires:
        return "Horaires non disponibles"
    
    now = datetime.now()
    current_day = NUM_TO_JOUR[now.weekday()]
    current_time = now.strftime("%H:%M")
    
    for horaire in horaires:
        if horaire['jour'] == current_day:
            if horaire.get('est_ferme', False):
                return "Fermé aujourd'hui"
            
            ouverture = horaire['heure_debut']
            fermeture = horaire['heure_fin']
            
            # Formater les heures avec zéro devant
            ouverture_fmt = ouverture if len(ouverture.split(':')[0]) == 2 else '0' + ouverture
            fermeture_fmt = fermeture if len(fermeture.split(':')[0]) == 2 else '0' + fermeture
            
            if ouverture_fmt <= current_time <= fermeture_fmt:
                return f"Ouvert • Ferme à {fermeture}"
            elif current_time < ouverture_fmt:
                return f"Fermé • Ouvre à {ouverture}"
            else:
                return "Fermé"
    
    return "Horaires non disponibles"


def get_open_status_color(horaires):
    """Obtenir la couleur du statut"""
    if not horaires:
        return "grey"
    
    is_open = is_garage_open_for_horaires(horaires)
    return "green" if is_open else "red"


def is_garage_open_for_horaires(horaires):
    """Vérifie si ouvert à partir des horaires seuls"""
    if not horaires:
        return False
    
    now = datetime.now()
    current_day = NUM_TO_JOUR[now.weekday()]
    current_time = now.strftime("%H:%M")
    
    for horaire in horaires:
        if horaire['jour'] == current_day:
            if horaire.get('est_ferme', False):
                return False
            
            ouverture = horaire['heure_debut']
            fermeture = horaire['heure_fin']
            
            if len(ouverture.split(':')[0]) == 1:
                ouverture = '0' + ouverture
            if len(fermeture.split(':')[0]) == 1:
                fermeture = '0' + fermeture
            
            return ouverture <= current_time <= fermeture
    
    return False


def get_today_hours(horaires):
    """Obtenir les horaires du jour"""
    if not horaires:
        return ""
    
    now = datetime.now()
    current_day = NUM_TO_JOUR[now.weekday()]
    
    for horaire in horaires:
        if horaire['jour'] == current_day:
            if horaire.get('est_ferme', False):
                return "Fermé aujourd'hui"
            ouverture = horaire['heure_debut']
            fermeture = horaire['heure_fin']
            return f"🕐 {ouverture} - {fermeture}"
    return ""