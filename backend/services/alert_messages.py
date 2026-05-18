# services/alert_messages.py
# Ce fichier ne touche PAS la BD → pas de modèles nécessaires ici.
# Les modèles servent uniquement quand on lit/écrit des données BD.

import random
from services.alert_messages_fr import ALERTES_FR, COMBINED_PATTERNS_FR

LANG_MAP = {'fr': ALERTES_FR}

PANNE_POSITIONS = {
    # Moteur
    36: "moteur", 37: "moteur", 38: "moteur", 39: "moteur",
    40: "moteur", 41: "moteur", 42: "moteur",
    # Batterie / Alternateur
    32: "batterie", 33: "batterie", 34: "batterie",
    # Freins
    46: "freins", 48: "freins", 49: "freins", 24: "freins",
    # Transmission / Embrayage
    43: "transmission", 44: "transmission", 45: "transmission",
    # Pneu
    50: "pneu", 25: "pneu",
    # Carburant
    51: "carburant",
    # Surchauffe
    52: "surchauffe", 37: "surchauffe",
}

POSITION_COORDS = {
    "moteur":       {"top": 0.25, "left": 0.45},
    "batterie":     {"top": 0.28, "left": 0.18},
    "freins":       {"top": 0.68, "left": 0.45},
    "transmission": {"top": 0.48, "left": 0.45},
    "pneu":         {"top": 0.28, "left": 0.72},
    "carburant":    {"top": 0.68, "left": 0.72},
    "surchauffe":   {"top": 0.18, "left": 0.45},
}

MECHANICAL_CODES = {
    24, 25, 32, 33, 34, 36, 37, 38, 39,
    40, 41, 42, 43, 44, 45, 46, 48, 49,
    50, 51, 52
}


def get_panne_position(code: int) -> dict:
    position_key = PANNE_POSITIONS.get(code, "moteur")
    coords = POSITION_COORDS.get(position_key, {"top": 0.5, "left": 0.5})
    return {
        "position_key": position_key,
        "pos_top":      coords["top"],
        "pos_left":     coords["left"],
    }


CRITICAL_CODES = {1, 2, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50}

ALERT_STYLES = {
    1:  ("#FF1744", "securite"),
    2:  ("#FF1744", "securite"),
    30: ("#FF1744", "securite"),
    46: ("#FF1744", "securite"),
    50: ("#FF1744", "securite"),
    9:  ("#FF6D00", "vigilance"),
    12: ("#FF6D00", "fatigue"),
    11: ("#FF6D00", "vigilance"),
    14: ("#FF6D00", "vigilance"),
    22: ("#FF6D00", "vitesse"),
    3:  ("#FF6D00", "securite"),
    23: ("#FFD600", "vitesse"),
    24: ("#FFD600", "freinage"),
    25: ("#FFD600", "freinage"),
    49: ("#FFD600", "freinage"),
    36: ("#2979FF", "mecanique"),
    37: ("#2979FF", "mecanique"),
    38: ("#2979FF", "mecanique"),
    39: ("#2979FF", "mecanique"),
    32: ("#2979FF", "mecanique"),
    33: ("#2979FF", "mecanique"),
    34: ("#2979FF", "mecanique"),
    40: ("#2979FF", "mecanique"),
    41: ("#2979FF", "mecanique"),
    42: ("#2979FF", "mecanique"),
    43: ("#2979FF", "mecanique"),
    44: ("#2979FF", "mecanique"),
    45: ("#2979FF", "mecanique"),
    48: ("#2979FF", "mecanique"),
    51: ("#2979FF", "mecanique"),
    52: ("#2979FF", "mecanique"),
    17: ("#00C853", "info"),
    18: ("#00C853", "info"),
    29: ("#00C853", "info"),
}

DEFAULT_STYLE = ("#607D8B", "info")


def get_alert_style(code: int) -> tuple:
    return ALERT_STYLES.get(code, DEFAULT_STYLE)


def get_alert_info(code: int, language: str = 'fr') -> tuple:
    alertes = LANG_MAP.get(language, ALERTES_FR)
    if code not in alertes:
        return "Alerte inconnue", "Problème non identifié"
    titre, variantes = alertes[code]
    return titre, random.choice(variantes)


def get_title(code: int, language: str = 'fr') -> str:
    alertes = LANG_MAP.get(language, ALERTES_FR)
    if code not in alertes:
        return "Alerte inconnue"
    return alertes[code][0]


def get_combined_pattern_message(pattern_name: str) -> str:
    messages = COMBINED_PATTERNS_FR.get(pattern_name, [])
    if messages:
        return random.choice(messages)
    return "Danger combiné détecté — arrêtez-vous immédiatement !"


def get_description(code: int, language: str = 'fr') -> str:
    alertes = LANG_MAP.get(language, ALERTES_FR)
    if code not in alertes:
        return "Problème non identifié"
    return alertes[code][1][0]