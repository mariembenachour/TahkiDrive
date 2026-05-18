# services/overpass_service.py
import httpx
import math
import json
import re
import os
import time
import asyncio
from typing import Optional
from groq import Groq
from dotenv import load_dotenv

load_dotenv()
client_groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Bounding box Tunisie : sud→nord, ouest→est
TUNISIA_BBOX = (30.2, 7.5, 37.5, 11.6)   # (lat_min, lon_min, lat_max, lon_max)

# ─── Cache mémoire (TTL 24h) ───────────────────────────────────────────────────
_groq_cache: dict[int, dict] = {}
_groq_cache_ts: float = 0.0
CACHE_TTL = 86400  # 24 heures


def _groq_cache_get(garage_id: int) -> Optional[dict]:
    global _groq_cache, _groq_cache_ts
    # Invalider le cache si TTL expiré
    if time.time() - _groq_cache_ts > CACHE_TTL:
        _groq_cache.clear()
        _groq_cache_ts = time.time()
        print("[CACHE] Cache Groq invalidé (TTL expiré)")
    return _groq_cache.get(garage_id)


def _groq_cache_set(hours_dict: dict[int, dict]) -> None:
    _groq_cache.update(hours_dict)


# ─── Fallback local (sans appel API) ──────────────────────────────────────────
def _fallback_hours(nom: str, shop_type: str) -> dict:
    """
    Génère des horaires réalistes sans appel API,
    basés sur des règles locales simples.
    """
    nom_lower = nom.lower()

    # Vulcanisation / pneus
    if any(k in nom_lower for k in ("pneu", "vulcani", "tyre", "boost")):
        return {"heure_ouverture": "07:00", "heure_fermeture": "19:30", "conge": None}

    # Carrosserie / peinture
    if any(k in nom_lower for k in ("carross", "peinture", "body")):
        return {"heure_ouverture": "08:00", "heure_fermeture": "17:00", "conge": "Samedi-Dimanche"}

    # Grandes marques / concessionnaires
    if any(k in nom_lower for k in (
        "volkswagen", "mercedes", "renault", "peugeot", "fiat",
        "toyota", "bmw", "hyundai", "kia", "nissan", "ford",
    )):
        return {"heure_ouverture": "08:00", "heure_fermeture": "17:30", "conge": "Dimanche"}

    # Diagnostic / électronique
    if any(k in nom_lower for k in ("diagnostic", "electr", "inject")):
        return {"heure_ouverture": "09:00", "heure_fermeture": "17:30", "conge": "Dimanche"}

    # Industriel / poids lourds
    if any(k in nom_lower for k in ("industri", "camion", "cobafil", "poids lourds")):
        return {"heure_ouverture": "07:00", "heure_fermeture": "17:00", "conge": "Dimanche"}

    # Petit garage généraliste (défaut)
    return {"heure_ouverture": "08:00", "heure_fermeture": "18:30", "conge": "Dimanche"}


# ─── Utilitaires ──────────────────────────────────────────────────────────────
def _haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return round(R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)), 2)


def _parse_opening_hours(oh: Optional[str]):
    if not oh:
        return None, None
    try:
        first_rule = oh.split(";")[0].strip()
        matches = re.findall(r'(\d{1,2}:\d{2})-(\d{1,2}:\d{2})', first_rule)
        if matches:
            return matches[0][0].zfill(5), matches[-1][1].zfill(5)
    except Exception:
        pass
    return None, None


def _compute_rating_from_osm(tags: dict) -> Optional[float]:
    score = 0.0
    name = tags.get("name", "")
    if name and name != "Garage sans nom":
        score += 1.0
    if tags.get("phone") or tags.get("contact:phone") or tags.get("contact:mobile"):
        score += 1.5
    if tags.get("addr:street") or tags.get("addr:full"):
        score += 1.0
    if tags.get("opening_hours"):
        score += 1.0
    if tags.get("website") or tags.get("contact:website"):
        score += 0.5
    return round(min(score, 5.0), 1) if score > 0 else None


# ─── Groq : génération par lots ───────────────────────────────────────────────
# Flag global : si 429 détecté, on arrête d'appeler Groq pour le reste de la journée
_groq_rate_limited_until: float = 0.0


def _generate_hours_with_groq(garages_list: list[dict]) -> dict:
    if not garages_list:
        return {}

    prompt = f"""Tu es un expert des habitudes commerciales des garages automobiles en Tunisie.

Pour chaque garage dans la liste, génère des horaires d'ouverture RÉALISTES et VARIÉS.
Les horaires doivent être différents selon le type et le nom du garage.

RÈGLES STRICTES pour la Tunisie :

1. Petit garage mécanique généraliste (nom comme "Garage", "Méca", "Auto"):
   - heure_ouverture: "07:30" ou "08:00"
   - heure_fermeture: "18:00" ou "19:00"  
   - conge: "Dimanche"

2. Grande marque / concessionnaire (Volkswagen, Mercedes, Renault, Peugeot, Fiat, Toyota, BMW, Hyundai):
   - heure_ouverture: "08:00" ou "08:30"
   - heure_fermeture: "17:00" ou "17:30"
   - conge: "Dimanche"

3. Vulcanisation / pneus (nom contient "pneu", "vulcani", "tyres", "boost"):
   - heure_ouverture: "07:00" ou "07:30"
   - heure_fermeture: "19:00" ou "20:00"
   - conge: null (ouvert 7j/7)

4. Carrosserie / peinture (nom contient "carross", "peinture", "body"):
   - heure_ouverture: "08:00"
   - heure_fermeture: "17:00"
   - conge: "Samedi-Dimanche"

5. Garage spécialisé / diagnostic (nom contient "diagnostic", "electr", "inject"):
   - heure_ouverture: "09:00" ou "10:00"
   - heure_fermeture: "17:00" ou "18:00"
   - conge: "Dimanche"

6. Garage industriel / poids lourds (nom contient "industri", "camion", "COBAFIL"):
   - heure_ouverture: "07:00"
   - heure_fermeture: "17:00"
   - conge: "Dimanche"

IMPORTANT: 
- Varie les horaires — ne donne pas les mêmes à tous
- Certains garages n'ont PAS de pause déjeuner (ouvert en continu)
- conge peut être: "Dimanche", "Samedi-Dimanche", ou null si ouvert 7j/7
- Pour les noms arabes: traite-les comme petit garage mécanique

Garages à traiter: {json.dumps(garages_list, ensure_ascii=False)}

Réponds UNIQUEMENT en JSON valide sans markdown:
{{
  "garages": [
    {{
      "id": 123456,
      "heure_ouverture": "08:00",
      "heure_fermeture": "18:00",
      "conge": "Dimanche"
    }}
  ]
}}"""

    try:
        response = client_groq.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1500,
            temperature=0.7,
        )
        raw = response.choices[0].message.content
        clean = re.sub(r"```json|```", "", raw).strip()
        data = json.loads(clean)
        result = {}
        for g in data.get("garages", []):
            result[int(g["id"])] = {
                "heure_ouverture": g.get("heure_ouverture", "08:00"),
                "heure_fermeture": g.get("heure_fermeture", "18:00"),
                "conge":           g.get("conge"),
            }
        print(f"[GROQ] Horaires générés pour {len(result)} garages")
        return result
    except Exception as e:
        err_str = str(e)
        if "429" in err_str or "rate_limit_exceeded" in err_str:
            print(f"[GROQ] 429 Rate limit — bascule fallback local pour tous les prochains batches")
            raise _GroqRateLimitError(err_str)
        print(f"[GROQ] Erreur génération horaires: {type(e).__name__}: {e}")
        return {
            int(g["id"]): _fallback_hours(g.get("nom", ""), g.get("shop_type", ""))
            for g in garages_list
        }


class _GroqRateLimitError(Exception):
    """Levée quand Groq retourne 429 — stoppe les batches suivants."""
    pass


# ─── Requêtes Overpass ────────────────────────────────────────────────────────
def _build_bbox_query(bbox: tuple) -> str:
    lat_min, lon_min, lat_max, lon_max = bbox
    bb = f"{lat_min},{lon_min},{lat_max},{lon_max}"
    return f"""
[out:json][timeout:60];
(
  node["shop"="car_repair"]({bb});
  way["shop"="car_repair"]({bb});
  node["amenity"="car_repair"]({bb});
  way["amenity"="car_repair"]({bb});
  node["craft"="car_repair"]({bb});
  way["craft"="car_repair"]({bb});
  node["shop"="vehicle_repair"]({bb});
  way["shop"="vehicle_repair"]({bb});
  node["shop"="tyres"]({bb});
  way["shop"="tyres"]({bb});
  node["shop"="car_parts"]({bb});
  way["shop"="car_parts"]({bb});
  node["amenity"="vehicle_inspection"]({bb});
  way["amenity"="vehicle_inspection"]({bb});
  node["name"~"[Gg]arage|[Mm]écanique|[Mm]ecanique|[Aa]uto|[Cc]arrosserie|[Vv]ulcanisation",i]({bb});
);
out center tags;
"""


def _build_around_query(lat: float, lon: float, radius_m: int) -> str:
    return f"""
[out:json][timeout:35];
(
  node["shop"="car_repair"](around:{radius_m},{lat},{lon});
  way["shop"="car_repair"](around:{radius_m},{lat},{lon});
  node["amenity"="car_repair"](around:{radius_m},{lat},{lon});
  way["amenity"="car_repair"](around:{radius_m},{lat},{lon});
  node["craft"="car_repair"](around:{radius_m},{lat},{lon});
  way["craft"="car_repair"](around:{radius_m},{lat},{lon});
  node["shop"="vehicle_repair"](around:{radius_m},{lat},{lon});
  way["shop"="vehicle_repair"](around:{radius_m},{lat},{lon});
  node["shop"="tyres"](around:{radius_m},{lat},{lon});
  way["shop"="tyres"](around:{radius_m},{lat},{lon});
  node["shop"="car_parts"](around:{radius_m},{lat},{lon});
  way["shop"="car_parts"](around:{radius_m},{lat},{lon});
  node["amenity"="vehicle_inspection"](around:{radius_m},{lat},{lon});
  way["amenity"="vehicle_inspection"](around:{radius_m},{lat},{lon});
  node["name"~"[Gg]arage|[Mm]écanique|[Mm]ecanique|[Aa]uto|[Cc]arrosserie|[Vv]ulcanisation",i](around:{radius_m},{lat},{lon});
);
out center tags;
"""


async def _fetch_overpass(query: str) -> list:
    try:
        async with httpx.AsyncClient(timeout=65) as client:
            resp = await client.post(
                OVERPASS_URL,
                data={"data": query},
                headers={"User-Agent": "TahkiDrive/1.0"},
            )
            print(f"[OSM] Status: {resp.status_code}")
            resp.raise_for_status()
            data = resp.json()
            elements = data.get("elements", [])
            print(f"[OSM] Elements reçus: {len(elements)}")
            return elements
    except Exception as e:
        # Affiche le type d'erreur pour un meilleur diagnostic
        print(f"[OSM] Erreur Overpass: {type(e).__name__}: {e}")
        return []


# ─── Parsing ──────────────────────────────────────────────────────────────────
def _parse_elements(
    elements: list,
    ref_lat: float,
    ref_lon: float,
) -> tuple[list[dict], list[dict]]:
    garages = []
    garages_need_hours = []
    seen_ids = set()

    for elem in elements:
        elem_id = elem["id"]
        if elem_id in seen_ids:
            continue
        seen_ids.add(elem_id)

        tags = elem.get("tags", {})

        if elem["type"] == "node":
            g_lat, g_lon = elem.get("lat"), elem.get("lon")
        else:
            center = elem.get("center", {})
            g_lat, g_lon = center.get("lat"), center.get("lon")

        if g_lat is None or g_lon is None:
            continue

        nom = (
            tags.get("name") or tags.get("name:fr")
            or tags.get("name:ar") or "Garage sans nom"
        )
        telephone = (
            tags.get("phone") or tags.get("contact:phone")
            or tags.get("contact:mobile") or ""
        )
        adresse_parts = list(filter(None, [
            tags.get("addr:housenumber"), tags.get("addr:street"),
            tags.get("addr:suburb"),     tags.get("addr:city"),
        ]))
        adresse = ", ".join(adresse_parts) or tags.get("addr:full") or ""

        oh_raw = tags.get("opening_hours")
        heure_ouverture, heure_fermeture = _parse_opening_hours(oh_raw)
        distance_km = _haversine(ref_lat, ref_lon, g_lat, g_lon)
        rating = _compute_rating_from_osm(tags)

        shop_type = (
            tags.get("shop") or tags.get("amenity")
            or tags.get("craft") or "car_repair"
        )

        garage = {
            "id":                elem_id,
            "nom":               nom,
            "telephone":         telephone,
            "adresse":           adresse,
            "latitude":          g_lat,
            "longitude":         g_lon,
            "rating":            rating,
            "heure_ouverture":   heure_ouverture,
            "heure_fermeture":   heure_fermeture,
            "conge":             None,
            "distance_km":       distance_km,
            "source":            "osm",
            "source_horaire":    "osm" if oh_raw else "ia",
            "opening_hours_raw": oh_raw,
            "website":           tags.get("website") or tags.get("contact:website"),
        }
        garages.append(garage)

        if not oh_raw:
            garages_need_hours.append({
                "id":        elem_id,
                "nom":       nom,
                "shop_type": shop_type,
            })

    return garages, garages_need_hours


# ─── Enrichissement Groq avec cache ───────────────────────────────────────────
async def _enrich_with_groq(garages: list[dict], garages_need_hours: list[dict]) -> list[dict]:
    """
    Injecte les horaires dans les garages :
    1. Depuis le cache si disponible
    2. Depuis Groq pour les non-cachés
    3. Fallback local si Groq échoue ou quota dépassé
    """
    if not garages_need_hours:
        return garages

    need_hours_ids = {g["id"] for g in garages_need_hours}

    # Séparer ce qui est déjà en cache vs ce qui doit être demandé à Groq
    uncached = [g for g in garages_need_hours if _groq_cache_get(g["id"]) is None]
    cached_count = len(garages_need_hours) - len(uncached)

    if cached_count:
        print(f"[CACHE] {cached_count} garages récupérés depuis le cache")

    # Appeler Groq uniquement pour les garages non cachés
    if uncached:
        print(f"[GROQ] {len(uncached)} garages à enrichir via Groq")
        batch_size = 20
        groq_hours: dict = {}
        rate_limited = False

        for i in range(0, len(uncached), batch_size):
            if rate_limited:
                # Stopper tous les batches suivants → fallback local
                remaining = uncached[i:]
                for g in remaining:
                    groq_hours[int(g["id"])] = _fallback_hours(
                        g.get("nom", ""), g.get("shop_type", "")
                    )
                break

            batch = uncached[i:i + batch_size]
            try:
                # Exécution SÉQUENTIELLE (await one by one, pas en parallèle)
                batch_result = await asyncio.get_event_loop().run_in_executor(
                    None, _generate_hours_with_groq, batch
                )
                groq_hours.update(batch_result)
            except _GroqRateLimitError:
                rate_limited = True
                # Ce batch → fallback local
                for g in batch:
                    groq_hours[int(g["id"])] = _fallback_hours(
                        g.get("nom", ""), g.get("shop_type", "")
                    )

        # Stocker en cache (Groq + fallback)
        _groq_cache_set(groq_hours)

    # Appliquer les horaires (cache ou fallback)
    for garage in garages:
        gid = garage["id"]
        if gid not in need_hours_ids:
            continue  # déjà des horaires OSM

        cached = _groq_cache_get(gid)
        if cached:
            garage["heure_ouverture"] = cached["heure_ouverture"]
            garage["heure_fermeture"] = cached["heure_fermeture"]
            garage["conge"]           = cached["conge"]
        else:
            # Dernier recours : fallback local
            nom       = garage.get("nom", "")
            shop_type = garage.get("source", "car_repair")
            fb = _fallback_hours(nom, shop_type)
            garage["heure_ouverture"] = fb["heure_ouverture"]
            garage["heure_fermeture"] = fb["heure_fermeture"]
            garage["conge"]           = fb["conge"]
            garage["source_horaire"]  = "fallback"

    return garages


# ─── API publique ──────────────────────────────────────────────────────────────

async def get_osm_garages(
    lat: float,
    lon: float,
    radius_m: int = 10_000,
    limit: int = 20,
    min_rating: Optional[float] = None,
) -> list[dict]:
    """Recherche de proximité (around). Utilisée pour /nearest."""
    query = _build_around_query(lat, lon, radius_m)
    elements = await _fetch_overpass(query)

    garages, garages_need_hours = _parse_elements(elements, lat, lon)

    # ── Trier et tronquer AVANT d'appeler Groq ──
    garages.sort(key=lambda x: x["distance_km"])
    garages = garages[:limit]
    kept_ids = {g["id"] for g in garages}
    garages_need_hours = [g for g in garages_need_hours if g["id"] in kept_ids]

    garages = await _enrich_with_groq(garages, garages_need_hours)

    if min_rating is not None:
        garages = [g for g in garages if (g.get("rating") or 0) >= min_rating]

    return garages


async def get_osm_garages_national(
    limit: int = 50,
    bbox: tuple = TUNISIA_BBOX,
) -> list[dict]:
    """
    Couvre tout le pays via bounding box.
    Utilisée pour /garages (tous) et /garages/status/all.
    """
    query = _build_bbox_query(bbox)
    elements = await _fetch_overpass(query)

    ref_lat = (bbox[0] + bbox[2]) / 2
    ref_lon = (bbox[1] + bbox[3]) / 2

    garages, garages_need_hours = _parse_elements(elements, ref_lat, ref_lon)

    # ── Trier et tronquer AVANT d'appeler Groq ──
    garages.sort(key=lambda x: x["distance_km"])
    garages = garages[:limit]
    kept_ids = {g["id"] for g in garages}
    garages_need_hours = [g for g in garages_need_hours if g["id"] in kept_ids]

    garages = await _enrich_with_groq(garages, garages_need_hours)

    return garages