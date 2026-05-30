import os
import json
import hmac
import base64
import hashlib
from datetime import datetime, timedelta
from db import get_connection
from models.compte_driver import CompteDriver
from models.administrateur import Administrateur
from models.device import Device
from models.vendor_token import VendorToken
from models.auth import UpdateProfileRequest

SECRET_KEY = os.getenv("SECRET_KEY", "tahkidrive_secret_key_2024")

def _b64_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def _b64_decode(s: str) -> bytes:
    s = s.strip()
    padding = 4 - len(s) % 4
    if padding != 4:
        s += "=" * padding
    return base64.urlsafe_b64decode(s)

def create_token(cin: str, scope: str, expires_minutes: int) -> str:
    header = _b64_encode(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(',', ':')).encode())
    expire = (datetime.utcnow() + timedelta(minutes=expires_minutes)).isoformat()
    payload = _b64_encode(json.dumps({"cin": cin, "scope": scope, "exp": expire}, separators=(',', ':')).encode())
    signing_input = f"{header}.{payload}"
    signature = _b64_encode(hmac.new(SECRET_KEY.encode(), signing_input.encode(), hashlib.sha256).digest())
    return f"{signing_input}.{signature}"

def decode_token(token: str) -> dict:
    try:
        token = token.strip()
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError(f"Token mal formé — {len(parts)} parties au lieu de 3")
        header_b64, payload_b64, sig_b64 = parts
        signing_input = f"{header_b64}.{payload_b64}"
        expected_sig = _b64_encode(hmac.new(SECRET_KEY.encode(), signing_input.encode(), hashlib.sha256).digest())
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

def create_setup_token(cin: str) -> str:
    return create_token(cin, scope="profile_setup", expires_minutes=60)

def create_access_token(cin: str) -> str:
    return create_token(cin, scope="full_access", expires_minutes=43200)

def create_admin_token(cin: str) -> str:
    return create_token(cin, scope="admin", expires_minutes=10080)

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed

def get_driver_by_email(email: str) -> CompteDriver | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE email = %s", (email,))
        row = cursor.fetchone()
        if not row:
            return None
        return CompteDriver(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_driver_by_email: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_driver_by_cin(cin: str) -> CompteDriver | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s", (cin,))
        row = cursor.fetchone()
        if not row:
            return None
        return CompteDriver(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_driver_by_cin: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_admin_by_email(email: str) -> Administrateur | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur WHERE email = %s", (email,))
        row = cursor.fetchone()
        if not row:
            return None
        return Administrateur(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_admin_by_email: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_admin_by_cin(cin: str) -> Administrateur | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur WHERE cin = %s", (cin,))
        row = cursor.fetchone()
        if not row:
            return None
        return Administrateur(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_admin_by_cin: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_device_by_id(device_id: int) -> Device | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device WHERE id = %s", (device_id,))
        row = cursor.fetchone()
        if not row:
            return None
        return Device(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_device_by_id: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_device_by_serial(serial: str) -> Device | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device WHERE serial = %s", (serial,))
        row = cursor.fetchone()
        if not row:
            return None
        return Device(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_device_by_serial: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def get_all_devices() -> list:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM device")
        rows = cursor.fetchall()
        result = []
        for row in rows:
            try:
                result.append(Device(**row))
            except Exception as e:
                print(f">>> [AUTH] Erreur conversion device: {e}")
        return result
    except Exception as e:
        print(f">>> [AUTH] Erreur get_all_devices: {e}")
        return []
    finally:
        cursor.close()
        conn.close()

def get_vendor_token(vendor_id: str, token_val: str) -> VendorToken | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT * FROM vendor_token
            WHERE vendor_id = %s AND token = %s
              AND uses_left > 0 AND expires_at > NOW()
        """, (vendor_id, token_val))
        row = cursor.fetchone()
        if not row:
            return None
        return VendorToken(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_vendor_token: {e}")
        return None
    finally:
        cursor.close()
        conn.close()

def decrement_vendor_token(token_id: int) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE vendor_token SET uses_left = uses_left - 1 WHERE id = %s", (token_id,))
        conn.commit()
    except Exception as e:
        print(f">>> [AUTH] Erreur decrement_vendor_token: {e}")
    finally:
        cursor.close()
        conn.close()

def is_vehicule_already_linked(matricule: str, exclude_cin: str = None) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if exclude_cin:
            cursor.execute("SELECT 1 FROM compte_driver WHERE vehicule_id = %s AND cin != %s", (matricule, exclude_cin))
        else:
            cursor.execute("SELECT 1 FROM compte_driver WHERE vehicule_id = %s", (matricule,))
        return cursor.fetchone() is not None
    except Exception as e:
        print(f">>> [AUTH] Erreur is_vehicule_already_linked: {e}")
        return False
    finally:
        cursor.close()
        conn.close()

def get_all_drivers() -> list:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver")
        rows = cursor.fetchall()
        result = []
        for row in rows:
            try:
                result.append(CompteDriver(**row))
            except Exception as e:
                print(f">>> [AUTH] Erreur conversion driver: {e}")
        return result
    except Exception as e:
        print(f">>> [AUTH] Erreur get_all_drivers: {e}")
        return []
    finally:
        cursor.close()
        conn.close()

def get_all_admins() -> list:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM administrateur")
        rows = cursor.fetchall()
        result = []
        for row in rows:
            try:
                result.append(Administrateur(**row))
            except Exception as e:
                print(f">>> [AUTH] Erreur conversion admin: {e}")
        return result
    except Exception as e:
        print(f">>> [AUTH] Erreur get_all_admins: {e}")
        return []
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
    except Exception as e:
        conn.rollback()
        print(f">>> [AUTH] Erreur create_driver: {e}")
        raise e
    finally:
        cursor.close()
        conn.close()

def link_vehicule_to_driver(cin: str, matricule: str) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE compte_driver SET vehicule_id = %s WHERE cin = %s", (matricule, cin))
        conn.commit()
    except Exception as e:
        print(f">>> [AUTH] Erreur link_vehicule_to_driver: {e}")
    finally:
        cursor.close()
        conn.close()

def update_driver_profile(cin: str, data: UpdateProfileRequest) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        fields = []
        values = []
        allowed = [
            "first_name", "last_name", "telephone", "driver_medically",
            "driving_training", "driving_safe", "fcm_token", "language", "email",
        ]
        data_dict = data.dict(exclude_none=True)
        for field in allowed:
            if field in data_dict:
                fields.append(f"{field} = %s")
                values.append(data_dict[field])

        if data.password:
            fields.append("password = %s")
            values.append(hash_password(data.password))
            fields.append("`password decrypted` = %s")
            values.append(data.password)
            fields.append("last_password_reset_date = %s")
            values.append(datetime.now())

        if not fields:
            return False

        query = f"UPDATE compte_driver SET {', '.join(fields)} WHERE cin = %s"
        values.append(cin)
        cursor.execute(query, tuple(values))
        conn.commit()
        return True
    except Exception as e:
        print(f">>> [AUTH] Erreur update_driver_profile: {e}")
        return False
    finally:
        cursor.close()
        conn.close()

def activate_driver(cin: str) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE compte_driver SET driver_authorized = 1 WHERE cin = %s", (cin,))
        conn.commit()
    except Exception as e:
        print(f">>> [AUTH] Erreur activate_driver: {e}")
    finally:
        cursor.close()
        conn.close()

def block_driver(cin: str) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE compte_driver SET driver_authorized = 0 WHERE cin = %s", (cin,))
        conn.commit()
    except Exception as e:
        print(f">>> [AUTH] Erreur block_driver: {e}")
    finally:
        cursor.close()
        conn.close()

def get_current_driver(cin: str) -> CompteDriver | None:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM compte_driver WHERE cin = %s", (cin,))
        row = cursor.fetchone()
        if not row:
            return None
        return CompteDriver(**row)
    except Exception as e:
        print(f">>> [AUTH] Erreur get_current_driver: {e}")
        return None
    finally:
        cursor.close()
        conn.close()


# ── Device mode ───────────────────────────────────────────────────────────────

def get_device_mode(cin: str) -> dict:
    """
    Lit tous les devices liés au véhicule du driver et retourne
    quelles parties de l'app afficher :
      has_cam     → true  → afficher DashboardChauffeur
      has_boitier → true  → afficher Dashboard voiture
    Si aucun device trouvé ou aucun type reconnu → false/false
    → l'app affichera un écran "aucun device associé"
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT d.type
            FROM device d
            JOIN compte_driver cd ON cd.vehicule_id = d.vehicule_id
            WHERE cd.cin = %s
        """, (cin,))
        rows = cursor.fetchall()

        has_cam     = any(r.get("type") == "cam"     for r in rows)
        has_boitier = any(r.get("type") == "boitier" for r in rows)

            # Caméra sans boîtier → impossible → on ignore la cam
        if not has_boitier:
                has_cam = False

        return {"has_cam": has_cam, "has_boitier": has_boitier}

    except Exception as e:
        print(f">>> [AUTH] Erreur get_device_mode: {e}")
        # En cas d'erreur DB → on retourne false/false aussi (safe)
        return {"has_cam": False, "has_boitier": False}
    finally:
        cursor.close()
        conn.close()
def update_fcm_token(cin: str, fcm_token: str) -> bool:
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # 1. Retirer ce token de tous les autres comptes
        cursor.execute(
            "UPDATE compte_driver SET fcm_token = NULL WHERE fcm_token = %s AND cin != %s",
            (fcm_token, cin)
        )
        removed = cursor.rowcount
        if removed > 0:
            print(f">>> [FCM] Token retiré de {removed} autre(s) compte(s) avant assignation à {cin}")

        # 2. Vérifier que le driver existe
        cursor.execute("SELECT cin FROM compte_driver WHERE cin = %s", (cin,))
        if not cursor.fetchone():
            return None  # controller lèvera le 404

        # 3. Assigner le token au bon compte
        cursor.execute(
            "UPDATE compte_driver SET fcm_token = %s WHERE cin = %s",
            (fcm_token, cin)
        )
        conn.commit()
        print(f">>> [FCM] Token assigné à {cin}")
        return True

    except Exception as e:
        conn.rollback()
        print(f">>> [FCM] Erreur update_fcm_token: {e}")
        raise e
    finally:
        cursor.close()
        conn.close()