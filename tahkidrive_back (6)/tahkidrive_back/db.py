# db.py
import pymysql

def get_connection():
    return pymysql.connect(
        host="127.0.0.1",
        user="root",
        password="mysql",
        database="tahkidrive",
        port=3306,
        cursorclass=pymysql.cursors.DictCursor  # optionnel mais pratique
    )