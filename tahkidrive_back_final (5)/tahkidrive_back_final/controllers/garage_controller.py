# controllers/garage_controller.py
from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from services.garage_service import (
    get_all_garages,
    get_top_rated_garages,
    get_nearest_garages,
    get_nearest_garages_with_filters,
    get_open_status_text,
    get_open_status_color,
    get_today_hours,
    is_garage_open
)

router = APIRouter()

@router.get("/garages")
def get_all_garages_endpoint():
    """Récupère tous les garages"""
    try:
        garages = get_all_garages()
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/garages/top")
def get_top_garages_endpoint():
    """Récupère TOUS les garages triés par note"""
    try:
        garages = get_top_rated_garages()
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/garages/nearest")
def get_nearest_garages_endpoint(
    limit: int = Query(10, ge=1, le=50),
    lat: float = Query(..., description="Latitude de l'utilisateur"),
    lon: float = Query(..., description="Longitude de l'utilisateur"),
    min_rating: Optional[float] = Query(None, ge=0, le=5)
):
    """
    Récupère les garages les plus proches de l'utilisateur
    """
    try:
        if min_rating is not None and min_rating > 0:
            garages = get_nearest_garages_with_filters(limit, min_rating, lat, lon)
        else:
            garages = get_nearest_garages(limit, lat, lon)
        
        if not garages:
            raise HTTPException(status_code=404, detail="Aucun garage trouvé à proximité")
        
        return garages
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/garages/{garage_id}/status")
def get_garage_status(garage_id: int):
    """Récupère le statut d'ouverture d'un garage"""
    try:
        garages = get_all_garages()
        garage = next((g for g in garages if g['id'] == garage_id), None)
        
        if not garage:
            raise HTTPException(status_code=404, detail="Garage non trouvé")
        
        is_open = is_garage_open(garage)
        status_text = get_open_status_text(
            garage.get('heure_ouverture'),
            garage.get('heure_fermeture'),
            garage.get('conge')
        )
        status_color = get_open_status_color(
            garage.get('heure_ouverture'),
            garage.get('heure_fermeture'),
            garage.get('conge')
        )
        today_hours = get_today_hours(
            garage.get('heure_ouverture'),
            garage.get('heure_fermeture'),
            garage.get('conge')
        )
        
        return {
            "garage_id": garage_id,
            "nom": garage['nom'],
            "is_open": is_open,
            "status_text": status_text,
            "status_color": status_color,
            "today_hours": today_hours,
            "heure_ouverture": garage.get('heure_ouverture'),
            "heure_fermeture": garage.get('heure_fermeture'),
            "conge": garage.get('conge')
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/garages/status/all")
def get_all_garages_status():
    """Récupère le statut d'ouverture de tous les garages"""
    try:
        garages = get_all_garages()
        result = []
        
        for garage in garages:
            result.append({
                "garage_id": garage['id'],
                "nom": garage['nom'],
                "is_open": is_garage_open(garage),
                "status_text": get_open_status_text(
                    garage.get('heure_ouverture'),
                    garage.get('heure_fermeture'),
                    garage.get('conge')
                ),
                "today_hours": get_today_hours(
                    garage.get('heure_ouverture'),
                    garage.get('heure_fermeture'),
                    garage.get('conge')
                )
            })
        
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))