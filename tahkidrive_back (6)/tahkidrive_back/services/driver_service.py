from db import get_connection

def get_driver_by_user_id(user_id: str):
    conn = get_connection()
    cursor = conn.cursor() 

    query = """
        SELECT 
            d.*, 
            u.email, 
            u.last_password_reset_date
        FROM driver d
        JOIN user u ON u.id = d.user_id
        WHERE d.user_id = %s
        LIMIT 1
    """
    
    cursor.execute(query, (user_id,))
    row = cursor.fetchone()
    
    cursor.close()
    conn.close()
    return row