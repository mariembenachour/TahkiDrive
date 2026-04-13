from pydantic import BaseModel
from typing import Optional

class OilChange(BaseModel):
    id: int
    id_maintenance: int
    odometre: Optional[float] = None
    air_f: Optional[str] = None
    type_air_f: Optional[str] = None
    engine_oil: Optional[str] = None
    type_engine_oil: Optional[str] = None
    fuel_f: Optional[str] = None
    type_fuel_f: Optional[str] = None
    oil_f: Optional[str] = None
    type_oil_f: Optional[str] = None
    separator_f: Optional[str] = None
    type_separator_f: Optional[str] = None
    oil_mark: Optional[str] = None
    air_conditioning_filter: Optional[str] = None
    brake_oil: Optional[str] = None
    type_brake_oil: Optional[str] = None
    cooling_oil: Optional[str] = None
    type_cooling_oil: Optional[str] = None
    windshield_washer_oil: Optional[str] = None
    type_windshield_washer_oil: Optional[str] = None
    hydraulic_suspension_oil: Optional[str] = None
    type_hydraulic_suspension_oil: Optional[str] = None
    gearbox_oil: Optional[str] = None
    type_gearbox_oil: Optional[str] = None
    direction_oil: Optional[str] = None
    type_direction_oil: Optional[str] = None
    lubrication: Optional[str] = None
    type_lubrication: Optional[str] = None
    hydrolique_oil: Optional[str] = None
    type_hydrolique_oil: Optional[str] = None
    boite_oil: Optional[str] = None
    type_boite_oil: Optional[str] = None
    pont_oil: Optional[str] = None
    type_pont_oil: Optional[str] = None
    graissage_oil: Optional[str] = None
    type_graissage_oil: Optional[str] = None
    reference_unique: Optional[str] = None