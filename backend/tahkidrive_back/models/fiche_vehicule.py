from pydantic import BaseModel
from datetime import date

class FicheVehicule(BaseModel):
    id_vehicule: int
    serial_number: str
    power_hp: float
    seating: int
    fuel: str
    load_capacity: float
    ptac: float
    pv: float
    payload: float
    fuel_tank_capacity: float
    id_fuel_provider: int
    fuel_card_nr: str
    fuel_card_pin: str
    fuel_control_module: str
    control_magnetic_driver: str
    first_installation: date
    last_change: date
    soumission_distributed_on: date
    soumission_available_till: date
    restriction: str
    comment: str
    date_purchase: date
    place_purchase: str