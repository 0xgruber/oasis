"""
Middleware setup for gateway service
"""

import time
from typing import Callable

import structlog
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from src.database import db_pool

logger = structlog.get_logger()


def setup_middleware(app: FastAPI) -> None:
    """Configure all middleware for the application"""

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # TODO: Configure based on environment
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Trusted host middleware (security)
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["*"],  # TODO: Configure based on environment
    )

    # Rate limit exceeded handler
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # Request logging middleware
    @app.middleware("http")
    async def log_requests(request: Request, call_next: Callable) -> Response:
        """Log all requests with timing"""
        start_time = time.time()

        # Get tenant info if available
        tenant_id = getattr(request.state, "tenant_id", None)
        tenant_name = getattr(request.state, "tenant_name", None)

        logger.info(
            "request_received",
            method=request.method,
            path=request.url.path,
            remote_addr=request.client.host if request.client else "unknown",
            tenant_id=tenant_id,
            tenant_name=tenant_name,
        )

        response = await call_next(request)

        duration_ms = (time.time() - start_time) * 1000

        logger.info(
            "request_completed",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2),
            tenant_id=tenant_id,
        )

        return response

    # Database lifecycle
    @app.on_event("startup")
    async def startup() -> None:
        """Connect to database on startup"""
        await db_pool.connect()

    @app.on_event("shutdown")
    async def shutdown() -> None:
        """Disconnect from database on shutdown"""
        await db_pool.disconnect()
