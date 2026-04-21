from fastapi import APIRouter, Request, HTTPException
from db import get_connection

router = APIRouter(prefix="/user", tags=["users"])

@router.get("/id")
async def get_user_id(device_id: int):
    """Récupère l'user_id à partir du device_id"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT uv.user_id
            FROM device d
            JOIN vehicule v ON v.id = d.vehicule_id
            JOIN user_vehicule uv ON uv.vehicule_id = v.id
            WHERE d.id = %s
            LIMIT 1
        """, (device_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            raise HTTPException(status_code=404, detail="User not found")
        
        return {"user_id": result['user_id']}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/device")
async def get_user_device(user_id: int):
    """Récupère le device_id à partir de l'user_id"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT d.id as device_id
            FROM device d
            JOIN vehicule v ON v.id = d.vehicule_id
            JOIN user_vehicule uv ON uv.vehicule_id = v.id
            WHERE uv.user_id = %s
            LIMIT 1
        """, (user_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            raise HTTPException(status_code=404, detail="No device found")
        
        return {"device_id": result['device_id']}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fcm-token")
async def update_fcm_token(request: Request):
    """Met à jour le token FCM d'un utilisateur"""
    try:
        data = await request.json()
        user_id = data.get('user_id')
        fcm_token = data.get('fcm_token')
        
        if not user_id or not fcm_token:
            raise HTTPException(status_code=400, detail="user_id and fcm_token required")
        
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE user SET fcm_token = %s WHERE id = %s
        """, (fcm_token, user_id))
        
        conn.commit()
        conn.close()
        
        return {"status": "success", "message": "Token updated"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/notifications")
async def get_notifications(user_id: int):
    """Récupère les notifications d'un utilisateur"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM notification 
            WHERE user_id = %s 
            ORDER BY created_at DESC 
            LIMIT 50
        """, (user_id,))
        
        notifs = cursor.fetchall()
        conn.close()
        
        return {"notifications": notifs}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/notifications/{notif_id}/read")
async def mark_notification_read(notif_id: int):
    """Marque une notification comme lue"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE notification SET is_readed = TRUE WHERE id = %s
        """, (notif_id,))
        
        conn.commit()
        conn.close()
        
        return {"status": "ok"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.patch("/notifications/read-all")
async def mark_all_read(user_id: int):
    """Marque toutes les notifications d'un user comme lues"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE notification SET is_readed = TRUE WHERE user_id = %s
        """, (user_id,))
        
        conn.commit()
        conn.close()
        
        return {"status": "ok"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))