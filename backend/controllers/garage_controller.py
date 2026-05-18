# controllers/garage_controller.py
from fastapi import APIRouter, HTTPException, Query
from services.overpass_service import get_osm_garages, get_osm_garages_national
from services.garage_service import (
    get_open_status_text,
    get_open_status_color,
    get_today_hours,
    is_garage_open,
)
from typing import Optional

router = APIRouter()


# ─── GET /garages ─────────────────────────────────────────────────────────────
@router.get("/garages")
async def get_all_garages_endpoint(
    limit: int = Query(50, ge=1, le=200),
):
    """Retourne tous les garages de Tunisie via Overpass (bounding box nationale)."""
    try:
        garages = await get_osm_garages_national(limit=limit)
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── GET /garages/top ─────────────────────────────────────────────────────────
# ⚠️ Doit être AVANT /garages/{garage_id}/status sinon FastAPI parse "top" comme int
@router.get("/garages/top")
async def get_top_garages_endpoint(
    limit: int = Query(10, ge=1, le=50),
):
    """Retourne les garages les mieux notés de Tunisie, triés par rating décroissant."""
    try:
        garages = await get_osm_garages_national(limit=200)
        top = sorted(
            [g for g in garages if g.get("rating") is not None],
            key=lambda g: g["rating"],
            reverse=True,
        )
        return top[:limit]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── GET /garages/nearest ──────────────────────────────────────────────────────
# ⚠️ Doit être AVANT /garages/{garage_id}/status pour la même raison
@router.get("/garages/nearest")
async def get_nearest_garages_endpoint(
    lat: float = Query(..., description="Latitude de l'utilisateur"),
    lon: float = Query(..., description="Longitude de l'utilisateur"),
    limit: int = Query(10, ge=1, le=50),
    radius_m: int = Query(10_000, ge=500, le=50_000),
    min_rating: Optional[float] = Query(None, ge=0, le=5),
):
    """Retourne les garages les plus proches de la position de l'utilisateur."""
    try:
        garages = await get_osm_garages(
            lat=lat,
            lon=lon,
            radius_m=radius_m,
            limit=limit,
            min_rating=min_rating,
        )
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── GET /garages/status/all ───────────────────────────────────────────────────
# ⚠️ Doit être AVANT /garages/{garage_id}/status
@router.get("/garages/status/all")
async def get_all_garages_status(
    limit: int = Query(50, ge=1, le=200),
):
    """Retourne le statut d'ouverture de tous les garages de Tunisie."""
    try:
        garages = await get_osm_garages_national(limit=limit)
        return [
            {
                "garage_id":   g["id"],
                "nom":         g["nom"],
                "is_open":     is_garage_open(g),
                "status_text": get_open_status_text(
                    g.get("heure_ouverture"),
                    g.get("heure_fermeture"),
                    g.get("conge"),
                ),
                "today_hours": get_today_hours(
                    g.get("heure_ouverture"),
                    g.get("heure_fermeture"),
                    g.get("conge"),
                ),
            }
            for g in garages
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── GET /garages/{garage_id}/status ──────────────────────────────────────────
# ⚠️ Routes avec paramètre dynamique TOUJOURS en dernier
@router.get("/garages/{garage_id}/status")
async def get_garage_status(garage_id: int):
    """Retourne le statut d'ouverture d'un garage par son ID OSM."""
    try:
        garages = await get_osm_garages_national(limit=500)
        garage = next((g for g in garages if g["id"] == garage_id), None)

        if not garage:
            raise HTTPException(status_code=404, detail="Garage non trouvé")

        return {
            "garage_id":       garage_id,
            "nom":             garage["nom"],
            "is_open":         is_garage_open(garage),
            "status_text":     get_open_status_text(
                garage.get("heure_ouverture"),
                garage.get("heure_fermeture"),
                garage.get("conge"),
            ),
            "status_color":    get_open_status_color(
                garage.get("heure_ouverture"),
                garage.get("heure_fermeture"),
                garage.get("conge"),
            ),
            "today_hours":     get_today_hours(
                garage.get("heure_ouverture"),
                garage.get("heure_fermeture"),
                garage.get("conge"),
            ),
            "heure_ouverture": garage.get("heure_ouverture"),
            "heure_fermeture": garage.get("heure_fermeture"),
            "conge":           garage.get("conge"),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))