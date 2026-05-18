# controllers/sav_controller.py
from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional
from pydantic import BaseModel
from datetime import date

from models.compte_driver import CompteDriver
from models.sav import SavCreate, SavUpdate

from services.sav_service import get_sav_by_driver, update_sav, delete_sav
from dependencies import get_current_user
from db import get_connection

router = APIRouter()


# ── Routes FIXES en premier ──────────────────────────────────────────────────

@router.get("/sav/maintenance-types")
def get_maintenance_types():
    """
    Pas de modèle ici — on retourne juste une liste de strings.
    Pas de données métier structurées → pas besoin de modèle Pydantic.
    """
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
    """
    Pas de changement de logique — get_sav_by_driver retourne maintenant
    des dicts issus de Sav + Garage (via .model_dump() dans le service).
    """
    try:
        return {"sav": get_sav_by_driver(user_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sav/me")
def create_sav(body: SavCreate, user_id: str = Depends(get_current_user)):
    """
    CORRECTION :
    Avant : cursor.execute("SELECT vehicule_id FROM compte_driver...") → dict brut.
    Maintenant : on met la ligne dans CompteDriver(**row) pour lire .vehicule_id.
    L'INSERT reste dans le controller (opération simple, pas de service dédié).
    """
    if body.type_sav not in ("maintenance", "accident"):
        raise HTTPException(status_code=400, detail="type_sav invalide")

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM compte_driver WHERE cin = %s LIMIT 1", (user_id,)
        )
        row = cursor.fetchone()
        if not row or not row["vehicule_id"]:
            raise HTTPException(status_code=404, detail="Véhicule introuvable")

        # Dict brut → modèle CompteDriver → lire .vehicule_id proprement
        driver = CompteDriver(**row)
        matricule = driver.vehicule_id

        garage_id = body.garage_id if body.garage_id is not None else 0
        cursor.execute("""
            INSERT INTO sav
                (type_sav, maintenance_type, description,
                 cost, date_reparation, vehicule_id, garage_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            body.type_sav, body.maintenance_type, body.description,
            body.cost, body.date_reparation, matricule, garage_id,
        ))
        conn.commit()
        return {"id": cursor.lastrowid, "message": "SAV créé"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# ── Routes avec paramètre EN DERNIER ─────────────────────────────────────────

@router.put("/sav/{id_sav}")
def route_update_sav(id_sav: int, body: SavUpdate, user_id: str = Depends(get_current_user)):
    """
    CORRECTION :
    Avant : update_sav(id_sav, user_id, body.dict()) — on passait un dict brut.
    Maintenant : update_sav attend un SavUpdate (modèle Pydantic), pas un dict.
    On passe body directement — plus de .dict().
    """
    try:
        ok = update_sav(id_sav, user_id, body)
        if not ok:
            raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
        return {"message": "SAV mis à jour"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/sav/{id_sav}")
def route_delete_sav(id_sav: int, user_id: str = Depends(get_current_user)):
    try:
        ok = delete_sav(id_sav, user_id)
        if not ok:
            raise HTTPException(status_code=404, detail="SAV introuvable ou non autorisé")
        return {"message": "SAV supprimé"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))