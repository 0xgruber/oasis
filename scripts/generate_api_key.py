#!/usr/bin/env python3
"""
O.A.S.I.S. API Key Generation Utility

Generates cryptographically secure API keys for tenants and stores them in the database.

Usage:
    python generate_api_key.py --tenant-id <UUID> [--description "Description"]
    
Example:
    python generate_api_key.py \
        --tenant-id "ffffffff-ffff-ffff-ffff-ffffffffffff" \
        --description "Production Vector agents (Linux + macOS)"
"""

import argparse
import secrets
import sys
import uuid
from datetime import datetime

try:
    import bcrypt
    import psycopg2
except ImportError as e:
    print(f"ERROR: Missing required dependency: {e}")
    print("\nInstall with: pip install bcrypt psycopg2-binary")
    sys.exit(1)


# Colors for terminal output
class Colors:
    BLUE = "\033[0;34m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    BOLD = "\033[1m"
    NC = "\033[0m"  # No Color


def print_header(text):
    """Print colored header"""
    print(f"{Colors.BLUE}{'=' * 80}{Colors.NC}")
    print(f"{Colors.BLUE}{text}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 80}{Colors.NC}")


def print_success(text):
    """Print success message"""
    print(f"{Colors.GREEN}✅ {text}{Colors.NC}")


def print_warning(text):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.NC}")


def print_error(text):
    """Print error message"""
    print(f"{Colors.RED}❌ {text}{Colors.NC}")


def generate_api_key() -> str:
    """
    Generate cryptographically secure API key

    Format: oasis_pk_{43_base64url_chars}
    Total length: ~52 characters

    Returns:
        str: The generated API key
    """
    # Generate 32 random bytes, encode as base64url (43 chars)
    random_bytes = secrets.token_urlsafe(32)
    return f"oasis_pk_{random_bytes}"


def hash_api_key(api_key: str) -> str:
    """
    Hash API key with bcrypt

    Args:
        api_key: The plaintext API key

    Returns:
        str: The bcrypt hash
    """
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(api_key.encode(), salt).decode()


def verify_tenant_exists(conn, tenant_id: str) -> tuple[bool, dict]:
    """
    Verify tenant exists and is active

    Args:
        conn: Database connection
        tenant_id: Tenant UUID

    Returns:
        tuple: (exists, tenant_info)
    """
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, name, is_active 
        FROM tenants 
        WHERE id = %s
    """,
        (tenant_id,),
    )

    result = cur.fetchone()
    cur.close()

    if not result:
        return False, {}

    return True, {"id": str(result[0]), "name": result[1], "is_active": result[2]}


def insert_api_key(
    conn, tenant_id: str, api_key: str, description: str
) -> tuple[str, datetime]:
    """
    Insert hashed API key into database

    Args:
        conn: Database connection
        tenant_id: Tenant UUID
        api_key: Plaintext API key
        description: Key description

    Returns:
        tuple: (key_id, created_at)
    """
    key_hash = hash_api_key(api_key)
    key_prefix = api_key[:8]  # "oasis_pk"
    key_id = str(uuid.uuid4())

    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO api_keys (id, tenant_id, key_hash, key_prefix, description, is_active)
        VALUES (%s, %s, %s, %s, %s, true)
        RETURNING id, created_at
    """,
        (key_id, tenant_id, key_hash, key_prefix, description),
    )

    result = cur.fetchone()
    conn.commit()
    cur.close()

    return str(result[0]), result[1]


def connect_database(host: str, port: int, dbname: str, user: str, password: str):
    """
    Connect to PostgreSQL database

    Args:
        host: Database host
        port: Database port
        dbname: Database name
        user: Database user
        password: Database password

    Returns:
        connection object
    """
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            dbname=dbname,
            user=user,
            password=password,
            connect_timeout=10,
        )
        return conn
    except psycopg2.OperationalError as e:
        print_error(f"Database connection failed: {e}")
        print("\nCheck that:")
        print("  1. PostgreSQL is running: docker compose ps postgresql")
        print("  2. Connection details are correct")
        print("  3. Port 15432 is accessible from host")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Generate O.A.S.I.S. API key for tenant",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate key for Internal tenant
  %(prog)s --tenant-id "ffffffff-ffff-ffff-ffff-ffffffffffff" \\
           --description "Production Vector agents"
  
  # Generate key with custom database connection
  %(prog)s --tenant-id "..." --host localhost --port 15432
        """,
    )

    parser.add_argument(
        "--tenant-id",
        required=True,
        help="Tenant UUID (e.g., ffffffff-ffff-ffff-ffff-ffffffffffff)",
    )
    parser.add_argument(
        "--description",
        default="API key generated via script",
        help="Key description (default: 'API key generated via script')",
    )
    parser.add_argument(
        "--host", default="localhost", help="PostgreSQL host (default: localhost)"
    )
    parser.add_argument(
        "--port", type=int, default=15432, help="PostgreSQL port (default: 15432)"
    )
    parser.add_argument(
        "--dbname", default="oasis", help="Database name (default: oasis)"
    )
    parser.add_argument(
        "--user", default="admin", help="Database user (default: admin)"
    )
    parser.add_argument(
        "--password", default="changeme", help="Database password (default: changeme)"
    )

    args = parser.parse_args()

    # Validate tenant_id is a valid UUID
    try:
        uuid.UUID(args.tenant_id)
    except ValueError:
        print_error(f"Invalid tenant ID format: {args.tenant_id}")
        print("Tenant ID must be a valid UUID")
        sys.exit(1)

    print_header("O.A.S.I.S. API Key Generator")

    # Connect to database
    print(f"Connecting to PostgreSQL at {args.host}:{args.port}...")
    conn = connect_database(args.host, args.port, args.dbname, args.user, args.password)
    print_success("Connected to database")

    # Verify tenant exists
    print(f"Verifying tenant: {args.tenant_id}...")
    exists, tenant_info = verify_tenant_exists(conn, args.tenant_id)

    if not exists:
        print_error(f"Tenant not found: {args.tenant_id}")
        print("\nList available tenants with:")
        print("  docker compose exec postgresql psql -U admin -d oasis \\")
        print('    -c "SELECT id, name, is_active FROM tenants;"')
        conn.close()
        sys.exit(1)

    if not tenant_info["is_active"]:
        print_error(f"Tenant is inactive: {tenant_info['name']}")
        print("Activate tenant before generating API keys")
        conn.close()
        sys.exit(1)

    print_success(f"Tenant found: {tenant_info['name']}")

    # Generate API key
    print("Generating cryptographically secure API key...")
    api_key = generate_api_key()
    print_success(f"Generated API key ({len(api_key)} characters)")

    # Insert into database
    print("Hashing with bcrypt and storing in database...")
    key_id, created_at = insert_api_key(conn, args.tenant_id, api_key, args.description)
    print_success("API key stored in database")

    conn.close()

    # Display results
    print_header("✅ API Key Generated Successfully")
    print(f"{Colors.BOLD}API Key ID:{Colors.NC}     {key_id}")
    print(f"{Colors.BOLD}Tenant ID:{Colors.NC}      {args.tenant_id}")
    print(f"{Colors.BOLD}Tenant Name:{Colors.NC}    {tenant_info['name']}")
    print(f"{Colors.BOLD}Description:{Colors.NC}    {args.description}")
    print(f"{Colors.BOLD}Created At:{Colors.NC}     {created_at}")
    print("=" * 80)

    print_warning("SAVE THIS KEY NOW - IT WILL NOT BE SHOWN AGAIN!")
    print("=" * 80)
    print(f"\n{Colors.BOLD}{api_key}{Colors.NC}\n")
    print("=" * 80)

    print("\n" + Colors.BOLD + "Next Steps:" + Colors.NC)
    print("\n1. Set as environment variable on Vector agents:")
    print(f'   export OASIS_API_KEY="{api_key}"')
    print("\n2. For persistent configuration (Linux):")
    print(
        "   echo 'OASIS_API_KEY=\"" + api_key + "\"' | sudo tee -a /etc/default/vector"
    )
    print("\n3. For macOS:")
    print("   echo 'export OASIS_API_KEY=\"" + api_key + "\"' >> ~/.zshrc")
    print("\n4. Verify key in database:")
    print("   docker compose exec postgresql psql -U admin -d oasis \\")
    print('     -c "SELECT key_prefix, description, created_at FROM api_keys \\')
    print("         WHERE id = '" + key_id + "';\"")
    print("=" * 80)
    print("")


if __name__ == "__main__":
    main()
