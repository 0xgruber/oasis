"""
Authentication middleware for API key validation
"""

from typing import Optional

import structlog
from fastapi import Request, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from src.database import db_pool

logger = structlog.get_logger()

security = HTTPBearer()


async def get_api_key_from_header(request: Request) -> str:
    """Extract API key from Authorization header"""
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    # Support both "Bearer <key>" and "<key>" formats
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    return auth_header


async def validate_tenant_api_key(request: Request) -> dict:
    """
    Dependency to validate API key and inject tenant info into request state

    Returns:
        Tenant information dict

    Raises:
        HTTPException: If API key is invalid
    """
    api_key = await get_api_key_from_header(request)

    tenant_info = await db_pool.validate_api_key(api_key)
    if not tenant_info:
        logger.warning(
            "authentication_failed",
            path=request.url.path,
            method=request.method,
            remote_addr=request.client.host if request.client else "unknown",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    # Store tenant info in request state for use in handlers
    request.state.tenant_id = tenant_info["tenant_id"]
    request.state.tenant_name = tenant_info["tenant_name"]
    request.state.eps_limit = tenant_info["eps_limit"]
    request.state.retention_days = tenant_info["retention_days"]

    logger.info(
        "authentication_success",
        tenant_id=tenant_info["tenant_id"],
        tenant_name=tenant_info["tenant_name"],
        path=request.url.path,
    )

    return tenant_info
