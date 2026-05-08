# auth_service.py
import os
import json
import hmac
import base64
import hashlib
from datetime import datetime, timedelta
from db import get_connection

SECRET_KEY = os.getenv("SECRET_KEY", "tahkidrive_secret_key_2024")


# ═══════════════════════════════════════════════════════════════════════════════
# JWT MAISON — stdlib uniquement
# ═══════════════════════════════════════════════════════════════════════════════

def _b64_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _b64_decode(s: str) -> bytes:
    s = s.strip()
    padding = 4 - len(s) % 4
    if padding != 4:
        s += "=" * padding
    return base64.urlsafe_b64decode(s)


def create_token(cin: str, scope: str, expires_minutes: int) -> str:
    # separators=(',', ':') pour éviter les espaces dans le JSON → base64 stable
    header = _b64_encode(json.dumps(
        {"alg": "HS256", "typ": "JWT"},
        separators=(',', ':')
    ).encode())

    expire = (datetime.utcnow() + timedelta(minutes=expires_minutes)).isoformat()

    payload = _b64_encode(json.dumps({
        "cin": cin,
        "scope": scope,
        "exp": expire,
    }, separators=(',', ':')).encode())

    signing_input = f"{header}.{payload}"

    signature = _b64_encode(
        hmac.new(
            SECRET_KEY.encode(),
            signing_input.encode(),
            hashlib.sha256
        ).digest()
    )
    return f"{signing_input}.{signature}"


def decode_token(token: str) -> dict:
    try:
        token = token.strip()  # supprime espaces/newlines parasites

        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError(f"Token mal formé — {len(parts)} parties au lieu de 3")

        header_b64, payload_b64, sig_b64 = parts
        signing_input = f"{header_b64}.{payload_b64}"

        expected_sig = _b64_encode(
            hmac.new(
                SECRET_KEY.encode(),
                signing_input.encode(),
                hashlib.sha256
            ).digest()
        )

        if not hmac.compare_digest(expected_sig, sig_b64):
            raise ValueError("Signature invalide")

        payload = json.loads(_b64_decode(payload_b64))

        exp = datetime.fromisoformat(payload["exp"])
        if datetime.utcnow() > exp:
            raise ValueError("Token expiré")

        return payload

    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f"Token invalide : {e}")


# Ligne à modifier dans auth_service.py
def create_setup_token(cin: str) -> str:
    # Allongé à 60 min pour laisser le temps de vérifier l'email
    return create_token(cin, scope="profile_setup", expires_minutes=60)


def create_access_token(cin: str) -> str:
    return create_token(cin, scope="full_access", expires_minutes=43200)


def create_admin_token(cin: str) -> str:
    return create_token(cin, scope="admin", expires_minutes=10080)


# ═══════════════════════════════════════════════════════════════════════════════
# PASSWORD — SHA256 stdlib
# ═══════════════════════════════════════════════════════════════════════════════

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed


# ═══════════════════════════════════════════════════════════════════════════════
# DB HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def get_driver_by_email(email: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE email = %s", (email,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_driver_by_cin(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s", (cin,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_admin_by_email(email: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur WHERE email = %s", (email,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_admin_by_cin(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur WHERE cin = %s", (cin,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_device_by_id(device_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device WHERE id = %s", (device_id,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_device_by_serial(serial: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device WHERE serial = %s", (serial,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def get_all_devices():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device")
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


def get_vendor_token(vendor_id: str, token_val: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT * FROM vendor_token
            WHERE vendor_id = %s AND token = %s
              AND uses_left > 0 AND expires_at > NOW()
        """, (vendor_id, token_val))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()


def decrement_vendor_token(token_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE vendor_token SET uses_left = uses_left - 1 WHERE id = %s",
            (token_id,)
        )
        conn.commit()
    finally:
        cursor.close()
        conn.close()


# Dans auth_service.py, remplacer is_vehicule_already_linked par :
def is_vehicule_already_linked(matricule: str, exclude_cin: str = None) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if exclude_cin:
            cursor.execute(
                "SELECT 1 FROM compte_driver WHERE vehicule_id = %s AND cin != %s",
                (matricule, exclude_cin)
            )
        else:
            cursor.execute(
                "SELECT 1 FROM compte_driver WHERE vehicule_id = %s",
                (matricule,)
            )
        return cursor.fetchone() is not None
    finally:
        cursor.close()
        conn.close()

def get_all_drivers():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver")
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


def get_all_admins():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur")
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


def create_driver(cin: str, email: str, password: str, fcm_token: str, language: str, code_qr: str) -> str:
    hashed = hash_password(password)
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO compte_driver
                (cin, email, password, fcm_token, language, codeQR,
                 driver_authorized, last_password_reset_date)
            VALUES (%s, %s, %s, %s, %s, %s, 0, NOW())
        """, (cin, email, hashed, fcm_token, language, code_qr))
        conn.commit()
        return cin
    finally:
        cursor.close()
        conn.close()


def link_vehicule_to_driver(cin: str, matricule: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE compte_driver SET vehicule_id = %s WHERE cin = %s",
            (matricule, cin)
        )
        conn.commit()
    finally:
        cursor.close()
        conn.close()


def update_driver_profile(cin: str, data: dict):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        fields = []
        values = []

        allowed_fields = [
            "cin",
            "first_name",
            "last_name",
            "telephone",
            "driver_medically",
            "driving_training",
            "driving_safe",
            "driver_authorized",
            "codeQR",
            "fcm_token",
            "language",
            "email",
            "vehicule_id"
        ]

        for field in allowed_fields:
            if field in data:
                fields.append(f"{field} = %s")
                values.append(data[field])

        # password
       # Section password dans auth_service.py
        if "password" in data and data["password"]:
            # 1. Mise à jour du hash (Sécurité)
            fields.append("password = %s")
            values.append(hash_password(data["password"]))

            # 2. Mise à jour du clair (Pour que tu puisses voir le changement en BD)
            # Vérifie bien le nom exact de ta colonne (ici j'utilise `password decrypted`)
            fields.append("`password decrypted` = %s") 
            values.append(data["password"])

            fields.append("last_password_reset_date = %s")
            values.append(datetime.now())

        if not fields:
            return False

        query = f"""
            UPDATE compte_driver
            SET {', '.join(fields)}
            WHERE cin = %s
        """

        values.append(cin)

        cursor.execute(query, tuple(values))
        conn.commit()

        return True

    finally:
        cursor.close()
        conn.close()


def activate_driver(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE compte_driver SET driver_authorized = 1 WHERE cin = %s", (cin,)
        )
        conn.commit()
    finally:
        cursor.close()
        conn.close()


def block_driver(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE compte_driver SET driver_authorized = 0 WHERE cin = %s", (cin,)
        )
        conn.commit()
    finally:
        cursor.close()
        conn.close()


def get_current_driver(cin: str):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s", (cin,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()
