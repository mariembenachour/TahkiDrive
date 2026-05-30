import pymysql
import os

def get_connection():
    try:
        conn = pymysql.connect(
            host="127.0.0.1",
            user="root",
            password="mysql",
            database="tahkidrive",
            port=3306,
            cursorclass=pymysql.cursors.DictCursor
        )
        print("✅ Connexion MySQL réussie")  # DEBUG
        return conn
    except Exception as e:
        print(f" Erreur connexion MySQL: {e}")
        raise  