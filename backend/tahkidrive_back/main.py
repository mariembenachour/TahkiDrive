from fastapi import FastAPI
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles

from controllers.dashboard_controller import router as dashboard_router
from controllers.fueling_controller import router as fuel_router
from controllers.arch_controller import router as odo_router
from controllers.tire_controller import router as tire_router
from controllers.event_controller import router as event_router
from controllers.driver_controller import router as driver_router
from controllers.sav_controller import router as sinistre_router
from controllers.maintenance_controller import router as maintenance_router  # 👈 AJOUT IMPORTANT
from controllers.garage_controller import router as garage_router  # ← AJOUTÉ

app = FastAPI()

load_dotenv()

# =========================
# STATIC
# =========================
app.mount("/static", StaticFiles(directory="static"), name="static")


# =========================
# ROUTERS
# =========================
app.include_router(dashboard_router)

app.include_router(maintenance_router)  # 👈 IMPORTANT (battery, brake, etc)

app.include_router(fuel_router)
app.include_router(odo_router)
app.include_router(tire_router)
app.include_router(event_router, prefix="/api/event")
app.include_router(driver_router)
app.include_router(sinistre_router)
app.include_router(garage_router)