# main.py
import os  # ← MANQUAIT — causait le crash au démarrage
from fastapi import FastAPI, Request, Depends, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles
import firebase_admin
from firebase_admin import credentials, auth

# Controllers
from controllers.path_controller import router as path_router
from controllers.dashboard_controller import router as dashboard_router
from controllers.arch_controller import router as odo_router
from controllers.garage_controller import router as garage_router
from controllers.event_controller import router as event_router
from controllers.maintenance_controller import router as maintenance_router
from controllers.driver_controller import router as driver_router
from controllers.sav_controller import router as sav_router
from controllers.notification_controller import router as notification_router
from controllers.agent_controller import router as agent_router
from controllers.auth_controller import router as auth_router
from controllers.admin_controller import router as admin_router
from controllers.chat_controller import router as chat_router
from controllers.dashboard_driver_controller import router as dashboard_driver_router

from services.scheduler import start_scheduler, stop_scheduler
from db import get_connection

load_dotenv()

# ============================================
# INITIALISATION FIREBASE ADMIN SDK
# ============================================
if not firebase_admin._apps:
    try:
        firebase_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
        cred = credentials.Certificate(firebase_path)
        firebase_admin.initialize_app(cred)
        print(">>> Firebase Admin initialisé avec succès")
    except Exception as e:
        print(f">>> Firebase Admin NON initialisé (mode dev sans credentials): {e}")
else:
    print(">>> Firebase Admin déjà actif (Reload)")


async def verify_firebase_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token manquant")
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        if not decoded_token.get("email_verified"):
            raise HTTPException(status_code=403, detail="Email non vérifié")
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Token invalide")


# ============================================
# LIFESPAN
# ============================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    print(">>> Démarrage de l'application...")
    start_scheduler()
    print(">>> Scheduler IA démarré")
    yield
    print(">>> Arrêt de l'application...")
    stop_scheduler()
    print(">>> Scheduler IA arrêté")


# ============================================
# APPLICATION FASTAPI
# ============================================
app = FastAPI(
    title="Vehicle AI Agent API",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================
# STATIC FILES
# ============================================
app.mount("/static", StaticFiles(directory="static"), name="static")


# ============================================
# ROUTES
# ============================================
app.include_router(path_router)
app.include_router(odo_router)
app.include_router(garage_router)
app.include_router(driver_router)
app.include_router(sav_router)
app.include_router(event_router)
app.include_router(dashboard_router)
app.include_router(maintenance_router)
app.include_router(notification_router)
app.include_router(agent_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(chat_router)
app.include_router(dashboard_driver_router)

@app.get("/debug/routes")
def list_routes():
    return [
        {"path": r.path, "methods": list(r.methods)}
        for r in app.routes
        if hasattr(r, "methods")
    ]

# ============================================
# HEALTH / STATUS
# ============================================
@app.get("/health")
def health():
    return {"status": "ok", "version": "2.0.0", "agent_ia": "active"}


@app.get("/worker-status")
def worker_status():
    from services.scheduler import scheduler
    jobs_info = [
        {
            "id":            job.id,
            "next_run_time": str(job.next_run_time) if job.next_run_time else None,
        }
        for job in scheduler.get_jobs()
    ]
    return {
        "status":           "running",
        "scheduler_running": scheduler.running,
        "jobs":             jobs_info,
 }
