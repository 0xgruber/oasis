"""
O.A.S.I.S. API Service
Query and management API with JWT authentication
"""

from datetime import timedelta
from typing import List, Optional, Dict, Any
import json
import os

import structlog
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import asyncpg
import clickhouse_connect
import httpx

from src.config import settings
from src.auth import verify_password, create_access_token, decode_access_token
from src.docker_client import get_service_status
from src.email_service import get_email_service

logger = structlog.get_logger()

app = FastAPI(
    title="O.A.S.I.S. API Service",
    description="Query and management API",
    version="0.1.0",
)


def _split_csv_env(name: str, default: List[str]) -> List[str]:
    raw = os.getenv(name)
    if not raw:
        return default
    return [part.strip() for part in raw.split(",") if part.strip()]


# Allow SOC portal access from configurable dev/proxy origins.
# In production, you should set `CORS_ALLOW_ORIGINS` to your portal domain(s).
app.add_middleware(
    CORSMiddleware,
    allow_origins=_split_csv_env(
        "CORS_ALLOW_ORIGINS",
        [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
        ],
    ),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# Global database connections
pg_pool: Optional[asyncpg.Pool] = None
ch_client: Optional[clickhouse_connect.driver.Client] = None


@app.on_event("startup")
async def startup():
    """Initialize database connections"""
    global pg_pool, ch_client

    pg_pool = await asyncpg.create_pool(
        host=settings.POSTGRES_HOST,
        port=settings.POSTGRES_PORT,
        database=settings.POSTGRES_DB,
        user=settings.POSTGRES_USER,
        password=settings.POSTGRES_PASSWORD,
        min_size=2,
        max_size=10,
    )

    ch_client = clickhouse_connect.get_client(
        host=settings.CLICKHOUSE_HOST,
        port=settings.CLICKHOUSE_PORT,
        database=settings.CLICKHOUSE_DB,
        username=settings.CLICKHOUSE_USER,
        password=settings.CLICKHOUSE_PASSWORD,
    )

    logger.info("api_service_started")


@app.on_event("shutdown")
async def shutdown():
    """Close database connections"""
    if pg_pool:
        await pg_pool.close()
    if ch_client:
        ch_client.close()
    logger.info("api_service_stopped")


# Models
class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    credential_id: str
    tenant_id: Optional[str]
    credential_type: str


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


class LogEntry(BaseModel):
    uuid: str
    tenant_id: str
    timestamp: int  # milliseconds since epoch
    severity_id: int
    category_uid: int
    class_uid: int
    message: Optional[str] = None
    raw_log: str
    ocsf: Dict[str, Any]
    ingested_at: int  # milliseconds since epoch


class LogsResponse(BaseModel):
    logs: List[LogEntry]
    total: int
    limit: int
    offset: int


class UpdateProfileRequest(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None


class UpdateProfileResponse(BaseModel):
    message: str
    user_id: str
    email: str
    username: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ChangePasswordResponse(BaseModel):
    message: str


class GlobalMessageRequest(BaseModel):
    message: str
    enabled: bool = True


class GlobalMessageResponse(BaseModel):
    message: str
    enabled: bool
    updated_at: Optional[str] = None
    updated_by: Optional[str] = None


class SMTPConfigRequest(BaseModel):
    enabled: bool = False
    host: str
    port: int = 587
    use_tls: bool = True
    use_ssl: bool = False
    username: str
    password: Optional[str] = None  # Optional for updates (only update if provided)
    from_email: str
    from_name: str = "O.A.S.I.S. Security Platform"


class SMTPConfigResponse(BaseModel):
    enabled: bool
    host: str
    port: int
    use_tls: bool
    use_ssl: bool
    username: str
    password_set: bool  # Don't expose actual password
    from_email: str
    from_name: str
    updated_at: Optional[str] = None
    updated_by: Optional[str] = None


class TestEmailRequest(BaseModel):
    recipient: str


class TestEmailResponse(BaseModel):
    success: bool
    message: str


# User Management Models
class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    role: str
    is_active: bool
    tenant_id: Optional[str] = None
    created_at: str
    updated_at: str
    last_login_at: Optional[str] = None


class UserListResponse(BaseModel):
    users: List[UserResponse]
    total: int
    limit: int
    offset: int


class CreateUserRequest(BaseModel):
    username: str
    email: str
    password: str
    role: str = "viewer"  # Default role
    is_active: bool = True


class InviteUserRequest(BaseModel):
    username: str
    email: str
    role: str = "viewer"  # Default role


class UpdateUserRequest(BaseModel):
    email: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None


class ResetPasswordRequest(BaseModel):
    user_id: str


class ResetPasswordResponse(BaseModel):
    success: bool
    message: str


# Dependencies
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Validate JWT and return current user"""
    token = credentials.credentials
    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    return {
        "user_id": user_id,
        "credential_id": payload.get("credential_id"),
        "credential_type": payload.get("credential_type", "customer_user"),
        "tenant_id": payload.get("tenant_id"),
        "username": payload.get("username"),
        "email": payload.get("email"),
    }


# Routes
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        service="api-service",
        version="0.1.0",
    )


@app.get("/services/status")
async def services_status(current_user: dict = Depends(get_current_user)):
    """
    Get real-time status of all OASIS Docker containers

    Requires authentication. Returns container health, state, uptime, and networks.
    """
    try:
        return get_service_status()
    except Exception as e:
        logger.error("service_status_query_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query service status: {str(e)}",
        )


@app.get("/stats/metrics")
async def get_system_metrics(current_user: dict = Depends(get_current_user)):
    """
    Get system-wide metrics (total logs, sources, ingestion rate)

    Proxies to metrics service

    Accessible by platform admins and SOC analysts
    """
    # Allow both platform admins and SOC analysts
    if current_user["credential_type"] not in ["platform_admin", "soc_analyst"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only platform administrators and SOC analysts can access system metrics",
        )

    try:
        # Proxy to metrics service
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.METRICS_SERVICE_URL}/metrics/system", timeout=10.0
            )
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        logger.error("metrics_service_http_error", status_code=e.response.status_code, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Metrics service error: {e.response.status_code}",
        )
    except httpx.RequestError as e:
        logger.error("metrics_service_connection_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to connect to metrics service",
        )
    except Exception as e:
        logger.error("metrics_proxy_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch system metrics: {str(e)}",
        )


@app.get("/agents")
async def list_agents(
    tenant_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """
    List all agents with computed status

    Proxies to metrics service

    Query Parameters:
        tenant_id: Optional tenant UUID filter

    Accessible by platform admins and SOC analysts
    """
    # Allow both platform admins and SOC analysts
    if current_user["credential_type"] not in ["platform_admin", "soc_analyst"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only platform administrators and SOC analysts can access agent information",
        )

    try:
        # Build query params
        params = {}
        if tenant_id:
            params["tenant_id"] = tenant_id

        # Proxy to metrics service
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.METRICS_SERVICE_URL}/metrics/agents",
                params=params,
                timeout=10.0,
            )
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        logger.error("agents_list_http_error", status_code=e.response.status_code, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Metrics service error: {e.response.status_code}",
        )
    except httpx.RequestError as e:
        logger.error("agents_list_connection_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to connect to metrics service",
        )
    except Exception as e:
        logger.error("agents_list_proxy_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agents list: {str(e)}",
        )


@app.get("/agents/status")
async def agent_status_breakdown(
    tenant_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """
    Get agent status breakdown counts

    Proxies to metrics service

    Query Parameters:
        tenant_id: Optional tenant UUID filter

    Accessible by platform admins and SOC analysts
    """
    # Allow both platform admins and SOC analysts
    if current_user["credential_type"] not in ["platform_admin", "soc_analyst"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only platform administrators and SOC analysts can access agent status",
        )

    try:
        # Build query params
        params = {}
        if tenant_id:
            params["tenant_id"] = tenant_id

        # Proxy to metrics service
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.METRICS_SERVICE_URL}/metrics/agents/status",
                params=params,
                timeout=10.0,
            )
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        logger.error("agent_status_http_error", status_code=e.response.status_code, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Metrics service error: {e.response.status_code}",
        )
    except httpx.RequestError as e:
        logger.error("agent_status_connection_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to connect to metrics service",
        )
    except Exception as e:
        logger.error("agent_status_proxy_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agent status breakdown: {str(e)}",
        )


@app.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Authenticate user and return JWT token

    Credentials:
    - SOC Analyst: user.soc / admin123
    - Platform Admin: user.admin / admin123
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    async with pg_pool.acquire() as conn:
        # Get credential from database with user join
        row = await conn.fetchrow(
            """
            SELECT 
                c.credential_id,
                c.user_id,
                c.username,
                c.password_hash,
                c.credential_type,
                c.is_active,
                u.email,
                u.full_name,
                u.tenant_id
            FROM credentials c
            JOIN users u ON c.user_id = u.id
            WHERE c.username = $1 AND c.is_active = true
            """,
            request.username,
        )

        if not row:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )

        # Verify password
        if not verify_password(request.password, row["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )

        # Update last_used_at for credential
        await conn.execute(
            "UPDATE credentials SET last_used_at = NOW() WHERE credential_id = $1",
            row["credential_id"],
        )

        # Create JWT token with new structure
        token_data = {
            "sub": str(row["user_id"]),
            "credential_id": str(row["credential_id"]),
            "credential_type": row["credential_type"],
            "username": row["username"],
            "email": row["email"],
            "tenant_id": str(row["tenant_id"]) if row["tenant_id"] else None,
        }

        access_token = create_access_token(token_data)

        logger.info(
            "user_login_success",
            user_id=str(row["user_id"]),
            credential_id=str(row["credential_id"]),
            username=row["username"],
            credential_type=row["credential_type"],
        )

        return LoginResponse(
            access_token=access_token,
            user_id=str(row["user_id"]),
            credential_id=str(row["credential_id"]),
            tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
            credential_type=row["credential_type"],
        )


@app.get("/account/profile")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """
    Get current user's profile information
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    async with pg_pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT id, tenant_id, username, email, role, created_at, last_login_at
            FROM users
            WHERE id = $1
            """,
            current_user["user_id"],
        )

        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        return {
            "user_id": str(row["id"]),
            "tenant_id": str(row["tenant_id"]) if row["tenant_id"] else None,
            "username": row["username"],
            "email": row["email"],
            "role": row["role"],
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            "last_login_at": row["last_login_at"].isoformat() if row["last_login_at"] else None,
        }


@app.put("/account/profile", response_model=UpdateProfileResponse)
async def update_profile(
    request: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Update current user's profile (email and/or username)

    At least one field (email or username) must be provided.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Validate that at least one field is provided
    if not request.email and not request.username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one field (email or username) must be provided",
        )

    async with pg_pool.acquire() as conn:
        # Check if username is already taken (if provided)
        if request.username:
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE username = $1 AND id != $2",
                request.username,
                current_user["user_id"],
            )
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Username already taken",
                )

        # Check if email is already taken (if provided)
        if request.email:
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE email = $1 AND id != $2",
                request.email,
                current_user["user_id"],
            )
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email already taken",
                )

        # Build UPDATE query dynamically based on provided fields
        update_fields = []
        params = []
        param_count = 1

        if request.email:
            update_fields.append(f"email = ${param_count}")
            params.append(request.email)
            param_count += 1

        if request.username:
            update_fields.append(f"username = ${param_count}")
            params.append(request.username)
            param_count += 1

        # Add user_id as last parameter
        params.append(current_user["user_id"])

        # Execute update
        query = f"""
            UPDATE users
            SET {", ".join(update_fields)}
            WHERE id = ${param_count}
            RETURNING id, email, username
        """

        row = await conn.fetchrow(query, *params)

        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        logger.info(
            "user_profile_updated",
            user_id=str(row["id"]),
            updated_email=bool(request.email),
            updated_username=bool(request.username),
        )

        return UpdateProfileResponse(
            message="Profile updated successfully",
            user_id=str(row["id"]),
            email=row["email"],
            username=row["username"],
        )


@app.put("/account/password", response_model=ChangePasswordResponse)
async def change_password(
    request: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Change current user's password

    Requires current password for verification.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Validate password strength (basic check)
    if len(request.new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 8 characters long",
        )

    async with pg_pool.acquire() as conn:
        # Get current password hash
        row = await conn.fetchrow(
            "SELECT password_hash FROM users WHERE id = $1",
            current_user["user_id"],
        )

        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        # Verify current password
        if not verify_password(request.current_password, row["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect",
            )

        # Hash new password
        from src.auth import hash_password

        new_hash = hash_password(request.new_password)

        # Update password
        await conn.execute(
            "UPDATE users SET password_hash = $1 WHERE id = $2",
            new_hash,
            current_user["user_id"],
        )

        logger.info(
            "user_password_changed",
            user_id=current_user["user_id"],
        )

        return ChangePasswordResponse(message="Password changed successfully")


@app.get("/system/message", response_model=GlobalMessageResponse)
async def get_global_message(current_user: dict = Depends(get_current_user)):
    """
    Get the global message configuration

    Returns the global message that should be displayed to all users.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    async with pg_pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT value, updated_at, updated_by
            FROM system_config
            WHERE key = 'global_message'
            """
        )

        if not row:
            # Return default empty message if not configured
            return GlobalMessageResponse(
                message="",
                enabled=False,
                updated_at=None,
                updated_by=None,
            )

        value = row["value"]
        # Parse JSON if it's a string
        if isinstance(value, str):
            value = json.loads(value)

        return GlobalMessageResponse(
            message=value.get("message", ""),
            enabled=value.get("enabled", False),
            updated_at=row["updated_at"].isoformat() if row["updated_at"] else None,
            updated_by=str(row["updated_by"]) if row["updated_by"] else None,
        )


@app.put("/system/message", response_model=GlobalMessageResponse)
async def update_global_message(
    request: GlobalMessageRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Update the global message configuration

    Only admin users can update the global message.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can update the global message",
        )

    async with pg_pool.acquire() as conn:
        # Upsert the global message
        await conn.execute(
            """
            INSERT INTO system_config (key, value, description, updated_by)
            VALUES ('global_message', $1::jsonb, 'Global message displayed to all users', $2)
            ON CONFLICT (key)
            DO UPDATE SET
                value = EXCLUDED.value,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW()
            """,
            json.dumps({"message": request.message, "enabled": request.enabled}),
            current_user["user_id"],
        )

        # Fetch updated row
        row = await conn.fetchrow(
            """
            SELECT value, updated_at, updated_by
            FROM system_config
            WHERE key = 'global_message'
            """
        )

        logger.info(
            "global_message_updated",
            user_id=current_user["user_id"],
            enabled=request.enabled,
        )

        value = row["value"]
        # Parse JSON if it's a string
        if isinstance(value, str):
            value = json.loads(value)

        return GlobalMessageResponse(
            message=value.get("message", ""),
            enabled=value.get("enabled", False),
            updated_at=row["updated_at"].isoformat() if row["updated_at"] else None,
            updated_by=str(row["updated_by"]) if row["updated_by"] else None,
        )


@app.get("/system/smtp", response_model=SMTPConfigResponse)
async def get_smtp_config(current_user: dict = Depends(get_current_user)):
    """
    Get SMTP configuration

    Only admin users can view SMTP configuration.
    Password is never returned, only password_set boolean.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can view SMTP configuration",
        )

    async with pg_pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT value, updated_at, updated_by
            FROM system_config
            WHERE key = 'smtp_config'
            """
        )

        if not row:
            # Return default empty config if not configured
            return SMTPConfigResponse(
                enabled=False,
                host="",
                port=587,
                use_tls=True,
                use_ssl=False,
                username="",
                password_set=False,
                from_email="",
                from_name="O.A.S.I.S. Security Platform",
                updated_at=None,
                updated_by=None,
            )

        value = row["value"]
        # Parse JSON if it's a string
        if isinstance(value, str):
            value = json.loads(value)

        return SMTPConfigResponse(
            enabled=value.get("enabled", False),
            host=value.get("host", ""),
            port=value.get("port", 587),
            use_tls=value.get("use_tls", True),
            use_ssl=value.get("use_ssl", False),
            username=value.get("username", ""),
            password_set=bool(value.get("password")),
            from_email=value.get("from_email", ""),
            from_name=value.get("from_name", "O.A.S.I.S. Security Platform"),
            updated_at=row["updated_at"].isoformat() if row["updated_at"] else None,
            updated_by=str(row["updated_by"]) if row["updated_by"] else None,
        )


@app.put("/system/smtp", response_model=SMTPConfigResponse)
async def update_smtp_config(
    request: SMTPConfigRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Update SMTP configuration

    Only admin users can update SMTP configuration.
    Password is stored securely and never returned in responses.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can update SMTP configuration",
        )

    async with pg_pool.acquire() as conn:
        # Get existing config to preserve password if not updating
        existing_row = await conn.fetchrow(
            "SELECT value FROM system_config WHERE key = 'smtp_config'"
        )

        existing_password = None
        if existing_row:
            existing_value = existing_row["value"]
            if isinstance(existing_value, str):
                existing_value = json.loads(existing_value)
            existing_password = existing_value.get("password")

        # Use provided password or keep existing
        password_to_store = request.password if request.password else existing_password

        # Build config object
        config = {
            "enabled": request.enabled,
            "host": request.host,
            "port": request.port,
            "use_tls": request.use_tls,
            "use_ssl": request.use_ssl,
            "username": request.username,
            "password": password_to_store,
            "from_email": request.from_email,
            "from_name": request.from_name,
        }

        # Upsert the SMTP config
        await conn.execute(
            """
            INSERT INTO system_config (key, value, description, updated_by)
            VALUES ('smtp_config', $1::jsonb, 'SMTP email server configuration', $2)
            ON CONFLICT (key)
            DO UPDATE SET
                value = EXCLUDED.value,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW()
            """,
            json.dumps(config),
            current_user["user_id"],
        )

        # Fetch updated row
        row = await conn.fetchrow(
            """
            SELECT value, updated_at, updated_by
            FROM system_config
            WHERE key = 'smtp_config'
            """
        )

        logger.info(
            "smtp_config_updated",
            user_id=current_user["user_id"],
            host=request.host,
            enabled=request.enabled,
        )

        value = row["value"]
        if isinstance(value, str):
            value = json.loads(value)

        return SMTPConfigResponse(
            enabled=value.get("enabled", False),
            host=value.get("host", ""),
            port=value.get("port", 587),
            use_tls=value.get("use_tls", True),
            use_ssl=value.get("use_ssl", False),
            username=value.get("username", ""),
            password_set=bool(value.get("password")),
            from_email=value.get("from_email", ""),
            from_name=value.get("from_name", "O.A.S.I.S. Security Platform"),
            updated_at=row["updated_at"].isoformat() if row["updated_at"] else None,
            updated_by=str(row["updated_by"]) if row["updated_by"] else None,
        )


@app.post("/system/smtp/test", response_model=TestEmailResponse)
async def test_smtp_config(
    request: TestEmailRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Test SMTP configuration by sending a test email

    Only admin users can test SMTP configuration.
    Sends a test email to verify SMTP settings are working.
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can test SMTP configuration",
        )

    try:
        # Get email service from database config
        email_service = await get_email_service(pg_pool)

        if not email_service:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="SMTP is not configured or not enabled",
            )

        # Send test email
        subject = "O.A.S.I.S. - SMTP Configuration Test"
        html_body = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #0a0e27 0%, #1a237e 100%); color: #00ff9f; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 8px 8px; }
        .success { background: #d4edda; color: #155724; padding: 15px; border-left: 4px solid #28a745; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>✅ SMTP Test Successful</h1>
        </div>
        <div class="content">
            <h2>Configuration Test</h2>
            <p>This is a test email from your O.A.S.I.S. platform.</p>
            
            <div class="success">
                <strong>✓ Success!</strong> Your SMTP configuration is working correctly.
            </div>
            
            <p>Your email system is properly configured and ready to:</p>
            <ul>
                <li>Send user invitation emails</li>
                <li>Send password reset emails</li>
                <li>Send system notifications</li>
            </ul>
            
            <p>You can now safely use email features in your O.A.S.I.S. deployment.</p>
        </div>
        <div class="footer">
            <p>This is a test message from O.A.S.I.S. SMTP Configuration</p>
        </div>
    </div>
</body>
</html>
"""

        text_body = """
✅ SMTP Test Successful

This is a test email from your O.A.S.I.S. platform.

Your SMTP configuration is working correctly and ready to:
- Send user invitation emails
- Send password reset emails
- Send system notifications

You can now safely use email features in your O.A.S.I.S. deployment.

---
This is a test message from O.A.S.I.S. SMTP Configuration
"""

        success = email_service.send_email(
            to_email=request.recipient,
            subject=subject,
            html_body=html_body,
            text_body=text_body,
        )

        if success:
            logger.info(
                "smtp_test_successful",
                user_id=current_user["user_id"],
                recipient=request.recipient,
            )
            return TestEmailResponse(
                success=True,
                message=f"Test email sent successfully to {request.recipient}",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send test email. Check SMTP configuration and logs.",
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "smtp_test_failed",
            error=str(e),
            user_id=current_user["user_id"],
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"SMTP test failed: {str(e)}",
        )


@app.get("/users", response_model=UserListResponse)
async def list_users(
    limit: int = 100,
    offset: int = 0,
    role: Optional[str] = None,
    is_active: Optional[bool] = None,
    current_user: dict = Depends(get_current_user),
):
    """
    List all users (admin only)

    Supports pagination and filtering by role and active status.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can list users",
        )

    try:
        # Build query with filters
        query = "SELECT id, username, email, role, is_active, tenant_id, created_at, updated_at, last_login_at FROM users WHERE 1=1"
        params = []
        param_count = 1

        if role is not None:
            query += f" AND role = ${param_count}"
            params.append(role)
            param_count += 1

        if is_active is not None:
            query += f" AND is_active = ${param_count}"
            params.append(is_active)
            param_count += 1

        query += " ORDER BY created_at DESC"
        query += f" LIMIT ${param_count} OFFSET ${param_count + 1}"
        params.extend([limit, offset])

        async with pg_pool.acquire() as conn:
            rows = await conn.fetch(query, *params)

            # Get total count
            count_query = "SELECT COUNT(*) FROM users WHERE 1=1"
            count_params = []
            if role is not None:
                count_query += " AND role = $1"
                count_params.append(role)
            if is_active is not None:
                param_num = len(count_params) + 1
                count_query += f" AND is_active = ${param_num}"
                count_params.append(is_active)

            total = await conn.fetchval(count_query, *count_params)

        users = [
            UserResponse(
                id=str(row["id"]),
                username=row["username"],
                email=row["email"],
                role=row["role"],
                is_active=row["is_active"],
                tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
                created_at=row["created_at"].isoformat(),
                updated_at=row["updated_at"].isoformat(),
                last_login_at=row["last_login_at"].isoformat() if row["last_login_at"] else None,
            )
            for row in rows
        ]

        logger.info(
            "users_listed",
            count=len(users),
            total=total,
            user_id=current_user["user_id"],
        )

        return UserListResponse(
            users=users,
            total=total,
            limit=limit,
            offset=offset,
        )

    except Exception as e:
        logger.error("users_list_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list users: {str(e)}",
        )


@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Get specific user details (admin only or own profile)
    """
    # Users can view their own profile, admins can view any profile
    if current_user["user_id"] != user_id and current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own profile",
        )

    try:
        async with pg_pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT id, username, email, role, is_active, tenant_id, created_at, updated_at, last_login_at
                FROM users
                WHERE id = $1
                """,
                user_id,
            )

            if not row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )

            return UserResponse(
                id=str(row["id"]),
                username=row["username"],
                email=row["email"],
                role=row["role"],
                is_active=row["is_active"],
                tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
                created_at=row["created_at"].isoformat(),
                updated_at=row["updated_at"].isoformat(),
                last_login_at=row["last_login_at"].isoformat() if row["last_login_at"] else None,
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("user_fetch_failed", error=str(e), user_id=user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user: {str(e)}",
        )


@app.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    request: CreateUserRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Create a new user with direct password (admin only)

    For inviting users via email, use POST /users/invite instead.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can create users",
        )

    # Validate role
    valid_roles = ["super_admin", "admin", "analyst", "viewer"]
    if request.role not in valid_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {', '.join(valid_roles)}",
        )

    try:
        from src.auth import hash_password

        password_hash = hash_password(request.password)

        async with pg_pool.acquire() as conn:
            # Check if username or email already exists
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE username = $1 OR email = $2",
                request.username,
                request.email,
            )

            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Username or email already exists",
                )

            # Create user
            row = await conn.fetchrow(
                """
                INSERT INTO users (username, email, password_hash, role, is_active)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id, username, email, role, is_active, tenant_id, created_at, updated_at, last_login_at
                """,
                request.username,
                request.email,
                password_hash,
                request.role,
                request.is_active,
            )

        logger.info(
            "user_created",
            user_id=str(row["id"]),
            username=request.username,
            role=request.role,
            created_by=current_user["user_id"],
        )

        return UserResponse(
            id=str(row["id"]),
            username=row["username"],
            email=row["email"],
            role=row["role"],
            is_active=row["is_active"],
            tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
            created_at=row["created_at"].isoformat(),
            updated_at=row["updated_at"].isoformat(),
            last_login_at=None,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("user_creation_failed", error=str(e), username=request.username)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user: {str(e)}",
        )


@app.post("/users/invite", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def invite_user(
    request: InviteUserRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Invite a new user via email (admin only)

    Generates a temporary password and sends an invitation email.
    User will need to use "Forgot Password" flow to set their own password.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can invite users",
        )

    # Validate role
    valid_roles = ["super_admin", "admin", "analyst", "viewer"]
    if request.role not in valid_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {', '.join(valid_roles)}",
        )

    try:
        from src.auth import hash_password
        import secrets
        import string

        # Generate temporary password (16 chars, alphanumeric + symbols)
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        temp_password = "".join(secrets.choice(alphabet) for _ in range(16))
        password_hash = hash_password(temp_password)

        async with pg_pool.acquire() as conn:
            # Check if username or email already exists
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE username = $1 OR email = $2",
                request.username,
                request.email,
            )

            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Username or email already exists",
                )

            # Create user with temporary password
            row = await conn.fetchrow(
                """
                INSERT INTO users (username, email, password_hash, role, is_active)
                VALUES ($1, $2, $3, $4, TRUE)
                RETURNING id, username, email, role, is_active, tenant_id, created_at, updated_at, last_login_at
                """,
                request.username,
                request.email,
                password_hash,
                request.role,
            )

            # Get SMTP config to check if email is enabled
            smtp_row = await conn.fetchrow(
                "SELECT value FROM system_config WHERE key = 'smtp_config'"
            )

            smtp_enabled = False
            if smtp_row and smtp_row["value"]:
                smtp_config = smtp_row["value"]
                smtp_enabled = smtp_config.get("enabled", False)

            # Send invitation email if SMTP is configured
            if smtp_enabled:
                try:
                    email_service = get_email_service(conn)
                    await email_service.send_user_invite(
                        to_email=request.email,
                        username=request.username,
                    )
                    logger.info(
                        "user_invitation_email_sent",
                        user_id=str(row["id"]),
                        email=request.email,
                    )
                except Exception as email_error:
                    logger.error(
                        "user_invitation_email_failed",
                        error=str(email_error),
                        user_id=str(row["id"]),
                        email=request.email,
                    )
                    # Don't fail the whole operation if email fails
            else:
                logger.warning(
                    "smtp_not_enabled",
                    message="User created but invitation email not sent (SMTP not configured)",
                    user_id=str(row["id"]),
                )

        logger.info(
            "user_invited",
            user_id=str(row["id"]),
            username=request.username,
            email=request.email,
            role=request.role,
            created_by=current_user["user_id"],
        )

        return UserResponse(
            id=str(row["id"]),
            username=row["username"],
            email=row["email"],
            role=row["role"],
            is_active=row["is_active"],
            tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
            created_at=row["created_at"].isoformat(),
            updated_at=row["updated_at"].isoformat(),
            last_login_at=None,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("user_invitation_failed", error=str(e), username=request.username)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to invite user: {str(e)}",
        )


@app.put("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    request: UpdateUserRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Update user details (admin only)

    Can update email, role, and active status.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can update users",
        )

    # Validate role if provided
    if request.role is not None:
        valid_roles = ["super_admin", "admin", "analyst", "viewer"]
        if request.role not in valid_roles:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid role. Must be one of: {', '.join(valid_roles)}",
            )

    try:
        async with pg_pool.acquire() as conn:
            # Check if user exists
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE id = $1",
                user_id,
            )

            if not existing:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )

            # Build update query dynamically
            updates = []
            params = []
            param_count = 1

            if request.email is not None:
                updates.append(f"email = ${param_count}")
                params.append(request.email)
                param_count += 1

            if request.role is not None:
                updates.append(f"role = ${param_count}")
                params.append(request.role)
                param_count += 1

            if request.is_active is not None:
                updates.append(f"is_active = ${param_count}")
                params.append(request.is_active)
                param_count += 1

            if not updates:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No fields to update",
                )

            # Add updated_at
            updates.append("updated_at = NOW()")
            params.append(user_id)

            query = f"""
                UPDATE users
                SET {", ".join(updates)}
                WHERE id = ${param_count}
                RETURNING id, username, email, role, is_active, tenant_id, created_at, updated_at, last_login_at
            """

            row = await conn.fetchrow(query, *params)

        logger.info(
            "user_updated",
            user_id=user_id,
            updated_by=current_user["user_id"],
            updates=request.dict(exclude_unset=True),
        )

        return UserResponse(
            id=str(row["id"]),
            username=row["username"],
            email=row["email"],
            role=row["role"],
            is_active=row["is_active"],
            tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
            created_at=row["created_at"].isoformat(),
            updated_at=row["updated_at"].isoformat(),
            last_login_at=row["last_login_at"].isoformat() if row["last_login_at"] else None,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("user_update_failed", error=str(e), user_id=user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user: {str(e)}",
        )


@app.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Delete user (admin only)

    Actually deactivates the user instead of hard delete for audit purposes.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can delete users",
        )

    # Prevent self-deletion
    if current_user["user_id"] == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own account",
        )

    try:
        async with pg_pool.acquire() as conn:
            # Check if user exists
            existing = await conn.fetchrow(
                "SELECT id FROM users WHERE id = $1",
                user_id,
            )

            if not existing:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )

            # Soft delete (deactivate)
            await conn.execute(
                "UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE id = $1",
                user_id,
            )

        logger.info(
            "user_deleted",
            user_id=user_id,
            deleted_by=current_user["user_id"],
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("user_deletion_failed", error=str(e), user_id=user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user: {str(e)}",
        )


@app.post("/users/{user_id}/reset-password", response_model=ResetPasswordResponse)
async def reset_user_password(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Reset user password and send temporary password via email (admin only)

    Generates a new temporary password and sends it via email.
    """
    # Check if user has admin credentials
    if current_user["credential_type"] != "platform_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can reset user passwords",
        )

    try:
        from src.auth import hash_password
        import secrets
        import string

        # Generate temporary password (16 chars, alphanumeric + symbols)
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        temp_password = "".join(secrets.choice(alphabet) for _ in range(16))
        password_hash = hash_password(temp_password)

        async with pg_pool.acquire() as conn:
            # Get user details
            user = await conn.fetchrow(
                "SELECT username, email FROM users WHERE id = $1",
                user_id,
            )

            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found",
                )

            # Update password
            await conn.execute(
                "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2",
                password_hash,
                user_id,
            )

            # Get SMTP config
            smtp_row = await conn.fetchrow(
                "SELECT value FROM system_config WHERE key = 'smtp_config'"
            )

            smtp_enabled = False
            if smtp_row and smtp_row["value"]:
                smtp_config = smtp_row["value"]
                smtp_enabled = smtp_config.get("enabled", False)

            # Send password reset email if SMTP is configured
            if smtp_enabled:
                try:
                    email_service = get_email_service(conn)
                    await email_service.send_password_reset(
                        to_email=user["email"],
                        username=user["username"],
                        temp_password=temp_password,
                    )
                    logger.info(
                        "password_reset_email_sent",
                        user_id=user_id,
                        email=user["email"],
                    )
                except Exception as email_error:
                    logger.error(
                        "password_reset_email_failed",
                        error=str(email_error),
                        user_id=user_id,
                    )
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Password reset but failed to send email. Please contact support.",
                    )
            else:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="SMTP is not configured. Cannot send password reset email.",
                )

        logger.info(
            "user_password_reset",
            user_id=user_id,
            reset_by=current_user["user_id"],
        )

        return ResetPasswordResponse(
            success=True,
            message=f"Password reset email sent to {user['email']}",
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("password_reset_failed", error=str(e), user_id=user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to reset password: {str(e)}",
        )


@app.get("/logs", response_model=LogsResponse)
async def query_logs(
    limit: int = 100,
    offset: int = 0,
    current_user: dict = Depends(get_current_user),
):
    """
    Query logs with tenant isolation

    Users can only query logs from their own tenant
    """
    if not ch_client:
        raise HTTPException(status_code=500, detail="ClickHouse not initialized")

    tenant_id = current_user["tenant_id"]
    if not tenant_id:
        raise HTTPException(status_code=400, detail="User has no tenant")

    # Enforce limits
    limit = min(limit, settings.MAX_QUERY_LIMIT)

    # Build table name
    table_name = f"logs_{tenant_id.replace('-', '_')}"

    def _get_table_columns() -> set[str]:
        if not ch_client:
            return set()
        result = ch_client.query(
            f"""
            SELECT name
            FROM system.columns
            WHERE database = '{settings.CLICKHOUSE_DB}' AND table = '{table_name}'
            """
        )
        return {row[0] for row in result.result_rows}

    try:
        cols = _get_table_columns()

        uuid_expr = (
            "uuid"
            if "uuid" in cols
            else "reinterpretAsUUID(MD5(concat(toString(timestamp), raw_log))) AS uuid"
        )
        message_expr = "message" if "message" in cols else "'' AS message"

        if "ingested_at" in cols:
            ingested_at_expr = "ingested_at"
        elif "indexed_at" in cols:
            ingested_at_expr = "indexed_at AS ingested_at"
        else:
            ingested_at_expr = "timestamp AS ingested_at"

        # Query logs (backward-compatible with older ClickHouse schemas)
        result = ch_client.query(
            f"""
            SELECT
                {uuid_expr},
                timestamp,
                tenant_id,
                raw_log,
                {message_expr},
                severity_id,
                category_uid,
                class_uid,
                ocsf,
                {ingested_at_expr}
            FROM {settings.CLICKHOUSE_DB}.{table_name}
            ORDER BY timestamp DESC
            LIMIT {limit} OFFSET {offset}
            """
        )

        # Get total count
        count_result = ch_client.query(f"SELECT count() FROM {settings.CLICKHOUSE_DB}.{table_name}")
        total = count_result.result_rows[0][0]

        # Format results
        logs: List[LogEntry] = []
        for row in result.result_rows:
            # Parse OCSF JSON from string
            try:
                ocsf_data = json.loads(row[8]) if isinstance(row[8], str) else row[8]
            except (json.JSONDecodeError, TypeError):
                ocsf_data = {}

            logs.append(
                LogEntry(
                    uuid=str(row[0]),
                    timestamp=int(row[1].timestamp() * 1000),
                    tenant_id=str(row[2]),
                    raw_log=row[3],
                    message=row[4] if row[4] else None,
                    severity_id=row[5],
                    category_uid=row[6],
                    class_uid=row[7],
                    ocsf=ocsf_data,
                    ingested_at=int(row[9].timestamp() * 1000),
                )
            )

        logger.info(
            "logs_queried",
            user_id=current_user["user_id"],
            tenant_id=tenant_id,
            count=len(logs),
        )

        return LogsResponse(
            logs=logs,
            total=total,
            limit=limit,
            offset=offset,
        )

    except Exception as e:
        logger.error("log_query_failed", error=str(e), tenant_id=tenant_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Query failed: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, log_level=settings.LOG_LEVEL.lower())
