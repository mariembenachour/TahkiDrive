from fastapi import APIRouter, HTTPException, Query
from services.overpass_service import get_osm_garages, get_osm_garages_national
from typing import Optional

router = APIRouter()


@router.get("/garages")
async def get_all_garages_endpoint(
    limit: int = Query(50, ge=1, le=200),
):
    try:
        garages = await get_osm_garages_national(limit=limit)
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/garages/top")
async def get_top_garages_endpoint(
    limit: int = Query(10, ge=1, le=50),
):
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


@router.get("/garages/nearest")
async def get_nearest_garages_endpoint(
    lat: float = Query(...),
    lon: float = Query(...),
    limit: int = Query(10, ge=1, le=50),
    radius_m: int = Query(10_000, ge=500, le=50_000),
    min_rating: Optional[float] = Query(None, ge=0, le=5),
):
    try:
        garages = await get_osm_garages(
            lat=lat, lon=lon,
            radius_m=radius_m,
            limit=limit,
            min_rating=min_rating,
        )
        return garages
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))