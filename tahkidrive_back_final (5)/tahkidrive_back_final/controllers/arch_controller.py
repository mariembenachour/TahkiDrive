from fastapi import APIRouter, HTTPException, Depends, Query
from services.arch_service import calculate_odo_stats, get_fuel_stats, _get_device_and_table
from db import get_connection
from dependencies import get_current_user

router = APIRouter()

@router.get("/odo")
def odo_stats(user_id: str = Depends(get_current_user)):
    data = calculate_odo_stats(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée ODO")
    return data

@router.get("/fuelings")

def fuel_stats(user_id: str = Depends(get_current_user)):
    data = get_fuel_stats(user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Aucune donnée carburant")
    return data

@router.get("/location")
def get_last_location(user_id: str = Depends(get_current_user)):
    _, table_name = _get_device_and_table(user_id)
    if not table_name:
        raise HTTPException(status_code=404, detail="Aucun device trouvé")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(f"""
                SELECT latitude, longitude FROM {table_name}
                ORDER BY date DESC LIMIT 1
            """)
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Aucune position trouvée")
            return {"latitude": row["latitude"], "longitude": row["longitude"]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()