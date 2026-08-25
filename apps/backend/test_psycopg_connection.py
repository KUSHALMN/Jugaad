import os
from dotenv import load_dotenv

load_dotenv(".env.local")
load_dotenv(".env")

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

print("SUPABASE_URL:", url)

try:
    import psycopg2
    print("psycopg2 is installed")
except ImportError:
    print("psycopg2 is NOT installed")

try:
    import asyncpg
    print("asyncpg is installed")
except ImportError:
    print("asyncpg is NOT installed")

try:
    import sqlalchemy
    print("sqlalchemy is installed")
except ImportError:
    print("sqlalchemy is NOT installed")
