"""
O.A.S.I.S. API Service
Query and management API with JWT authentication
"""

from datetime import timedelta
from typing import List, Optional

import structlog
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import asyncpg
import clickhouse_connect

from src.config import settings
from src.auth import verify_password, create_access_token, decode_access_token

logger = structlog.get_logger()

app = FastAPI(
    title="O.A.S.I.S. API Service",
    description="Query and management API",
    version="0.1.0",
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
    tenant_id: Optional[str]
    role: str


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


class LogEntry(BaseModel):
    timestamp: str
    tenant_id: str
    raw_log: str
    severity_id: int


class LogsResponse(BaseModel):
    logs: List[LogEntry]
    total: int
    limit: int
    offset: int


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
        "tenant_id": payload.get("tenant_id"),
        "role": payload.get("role", "tenant_user"),
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


@app.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Authenticate user and return JWT token

    Default credentials: admin / Admin123!
    """
    if not pg_pool:
        raise HTTPException(status_code=500, detail="Database not initialized")

    async with pg_pool.acquire() as conn:
        # Get user from database
        row = await conn.fetchrow(
            """
            SELECT id, tenant_id, username, password_hash, role, is_active
            FROM users
            WHERE username = $1
            """,
            request.username,
        )

        if not row or not row["is_active"]:
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

        # Update last login
        await conn.execute(
            "UPDATE users SET last_login_at = NOW() WHERE id = $1",
            row["id"],
        )

        # Create JWT token
        token_data = {
            "sub": str(row["id"]),
            "tenant_id": str(row["tenant_id"]) if row["tenant_id"] else None,
            "role": row["role"],
            "username": row["username"],
        }

        access_token = create_access_token(token_data)

        logger.info(
            "user_login_success",
            user_id=str(row["id"]),
            username=row["username"],
            role=row["role"],
        )

        return LoginResponse(
            access_token=access_token,
            user_id=str(row["id"]),
            tenant_id=str(row["tenant_id"]) if row["tenant_id"] else None,
            role=row["role"],
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

    try:
        # Query logs
        result = ch_client.query(
            f"""
            SELECT timestamp, tenant_id, raw_log, severity_id
            FROM {settings.CLICKHOUSE_DB}.{table_name}
            ORDER BY timestamp DESC
            LIMIT {limit} OFFSET {offset}
            """
        )

        # Get total count
        count_result = ch_client.query(f"SELECT count() FROM {settings.CLICKHOUSE_DB}.{table_name}")
        total = count_result.result_rows[0][0]

        # Format results
        logs = []
        for row in result.result_rows:
            logs.append(
                LogEntry(
                    timestamp=str(row[0]),
                    tenant_id=str(row[1]),
                    raw_log=row[2],
                    severity_id=row[3],
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
