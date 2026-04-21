# main.py
from fastapi import FastAPI, Request
from controllers.dashboard_controller import router as dashboard_router
from controllers.arch_controller import router as odo_router
from controllers.garage_controller import router as garage_router
from controllers.event_controller import router as event_router
from controllers.maintenance_controller import router as maintenance_router
from controllers.driver_controller import router as driver_router
from controllers.sav_controller import router as sav_router
from controllers.user_controller import router as user_router
from controllers.notification_controller import router as notification_router  # ← AJOUTE

from dotenv import load_dotenv  
from fastapi.staticfiles import StaticFiles
from apscheduler.schedulers.background import BackgroundScheduler
from services.notification_worker import process_new_events
from db import get_connection

app = FastAPI()
load_dotenv()

# Démarrer le scheduler pour les notifications toutes les 30 secondes
scheduler = BackgroundScheduler()
scheduler.add_job(process_new_events, 'interval', seconds=30)
scheduler.start()

# Endpoint pour sauvegarder le token FCM (version corrigée avec driver)
@app.post("/update-fcm-token")
async def update_fcm_token(request: Request):
    try:
        data = await request.json()
        driver_id = data.get('driver_id')
        fcm_token = data.get('fcm_token')
        
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE driver SET fcm_token = %s WHERE user_id = %s
        """, (fcm_token, driver_id))  # ← user_id, pas id
        conn.commit()
        conn.close()
        
        print(f"✅ Token FCM mis à jour pour driver {driver_id}")
        return {"status": "success", "message": "Token updated"}
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return {"status": "error", "message": str(e)}

# Montage des dossiers statiques et routes
app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(odo_router)
app.include_router(garage_router) 
app.include_router(driver_router)
app.include_router(sav_router)
app.include_router(event_router)
app.include_router(user_router)
app.include_router(dashboard_router)
app.include_router(maintenance_router)
app.include_router(notification_router)  # ← AJOUTE le router des notifications

# Optionnel: endpoint pour vérifier que le worker tourne
@app.get("/worker-status")
def worker_status():
    return {
        "status": "running",
        "interval_seconds": 30,
        "next_run": str(scheduler.get_job('process_new_events').next_run_time) if scheduler.get_job('process_new_events') else None
    }