# controllers/user_controller.py
# Nouveau schéma :
#   - plus de tables user / user_vehicule / notification
#   - compte_driver.cin (PK, varchar 8) remplace user_id
#   - compte_driver.vehicule_id = matricule (FK → vehicule.matricule)
#   - fcm_token stocké dans compte_driver

from fastapi import APIRouter, Request, HTTPException
from db import get_connection

router = APIRouter(prefix="/user", tags=["users"])


# ──────────────────────────────────────────────
# GET CIN depuis device_id
# ──────────────────────────────────────────────
@router.get("/id")
async def get_driver_cin_from_device(device_id: int):
    """Retourne le CIN du driver à partir d'un device_id."""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        # device.vehicule_id (matricule) → compte_driver.vehicule_id
        cursor.execute("""
            SELECT d.cin
            FROM device dev
            JOIN compte_driver d ON d.vehicule_id = dev.vehicule_id
            WHERE dev.id = %s
            LIMIT 1
        """, (device_id,))

        result = cursor.fetchone()
        cursor.close()
        conn.close()

        if not result:
            raise HTTPException(status_code=404, detail="Driver introuvable pour ce device")

        return {"cin": result["cin"]}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────
# GET device_id depuis cin
# ──────────────────────────────────────────────
@router.get("/device")
async def get_device_from_cin(cin: str):
    """Retourne le device_id associé au CIN du driver."""
    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT dev.id AS device_id
            FROM device dev
            JOIN compte_driver d ON d.vehicule_id = dev.vehicule_id
            WHERE d.cin = %s
            LIMIT 1
        """, (cin,))

        result = cursor.fetchone()
        cursor.close()
        conn.close()

        if not result:
            raise HTTPException(status_code=404, detail="Aucun device trouvé")

        return {"device_id": result["device_id"]}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────
# UPDATE FCM TOKEN
# ──────────────────────────────────────────────
@router.post("/fcm-token")
async def update_fcm_token(request: Request):
    """Met à jour le token FCM dans compte_driver."""
    try:
        data      = await request.json()
        cin       = data.get("cin")
        fcm_token = data.get("fcm_token")

        if not cin or not fcm_token:
            raise HTTPException(status_code=400, detail="cin et fcm_token requis")

        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "UPDATE compte_driver SET fcm_token = %s WHERE cin = %s",
            (fcm_token, cin)
        )
        conn.commit()
        cursor.close()
        conn.close()

        return {"status": "success", "message": "Token updated"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))