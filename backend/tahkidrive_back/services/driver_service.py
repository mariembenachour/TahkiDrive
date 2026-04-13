from db import get_connection

def get_driver_by_user_id(user_id: str):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT 
            d.*,
            u.id          as user_id,
            u.createdat,
            u.display_name,
            u.email       as user_email,
            u.enabled,
            u.lastpasswordresetdate,
            u.username,
            u.codeQR
        FROM driver d
        JOIN user u ON u.id = d.sub_user_id
        WHERE d.sub_user_id = %s
        LIMIT 1
    """, (user_id,))

    row = cursor.fetchone()
    cursor.close()
    conn.close()

    return row