from fastapi import APIRouter, HTTPException
from services.arch_service import calculate_odo_stats
from db import get_connection

router = APIRouter()

@router.get("/odo")
def odo_stats():
    stats = calculate_odo_stats()
    if not stats:
        return {"message": "Aucune donnée"}
    return stats

@router.get("/location")
def get_last_location():
    try:
        conn = get_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT latitude, longitude 
                FROM arch_700003 
                ORDER BY date DESC 
                LIMIT 1
            """)
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Aucune position trouvée")
            return {
                "latitude": row["latitude"],
                "longitude": row["longitude"]
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()