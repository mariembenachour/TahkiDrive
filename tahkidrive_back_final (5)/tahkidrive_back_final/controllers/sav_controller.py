from fastapi import APIRouter, HTTPException, Depends, Query
from services.sav_service import get_sav_by_driver
from typing import Optional
from dependencies import get_current_user
from pydantic import BaseModel
from datetime import date
from db import get_connection

router = APIRouter()

class SavCreate(BaseModel):
    type_sav: str
    date_reparation: date
    maintenance_type: Optional[str] = None
    description: Optional[str] = None
    cost: Optional[float] = None
    garage_id: Optional[int] = None

# ── 1. Routes FIXES en premier ──────────────────────

@router.get("/sav/maintenance-types")
def get_maintenance_types():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT DISTINCT maintenance_type 
            FROM sav 
            WHERE maintenance_type IS NOT NULL
            ORDER BY maintenance_type
        """)
        rows = cursor.fetchall()
        types_db = [row["maintenance_type"] for row in rows]
        if not types_db:
            return ["Freinage", "Pneus", "Batterie",
                    "Distribution", "Embrayage", "Moteur"]
        return types_db
    finally:
        cursor.close()
        conn.close()

@router.get("/sav/me")
def get_my_sav(user_id: str = Depends(get_current_user)):
    try:
        return {"sav": get_sav_by_driver(user_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sav/me")
def create_sav(body: SavCreate, user_id: str = Depends(get_current_user)):
    if body.type_sav not in ("maintenance", "accident"):
        raise HTTPException(status_code=400, detail="type_sav invalide")
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT vehicule_id FROM compte_driver WHERE cin = %s LIMIT 1", (user_id,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            raise HTTPException(status_code=404, detail="Véhicule introuvable")
        matricule = row["vehicule_id"]
        garage_id = body.garage_id if body.garage_id is not None else 0
        cursor.execute("""
            INSERT INTO sav 
                (type_sav, maintenance_type, description,
                cost, date_reparation, vehicule_id, garage_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            body.type_sav, body.maintenance_type, body.description,
            body.cost, body.date_reparation, matricule, garage_id
        ))
        conn.commit()
        return {"id": cursor.lastrowid, "message": "SAV créé"}
    finally:
        conn.close()

# ── 2. Routes avec paramètre EN DERNIER ─────────────
from services.sav_service import get_sav_by_driver, update_sav, delete_sav

@router.put("/sav/{id_sav}")
def route_update_sav(id_sav: int, body: SavCreate, user_id: str = Depends(get_current_user)):
    ok = update_sav(id_sav, user_id, body.dict())
    if not ok:
        raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
    return {"message": "SAV mis à jour"}

@router.delete("/sav/{id_sav}")
def route_delete_sav(id_sav: int, user_id: str = Depends(get_current_user)):
    ok = delete_sav(id_sav, user_id)
    if not ok:
        raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
    return {"message": "SAV supprimé"}