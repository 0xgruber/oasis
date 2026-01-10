"""
O.A.S.I.S. Gateway Service
Handles API key authentication, rate limiting, and log forwarding
"""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

import structlog
from fastapi import FastAPI
from slowapi import Limiter
from slowapi.util import get_remote_address

from src.config import settings
from src.middleware import setup_middleware
from src.routes import health, ingest, syslog, agents

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler"""
    from src.database import db_pool

    logger.info(
        "gateway_starting",
        gateway_type=settings.GATEWAY_TYPE,
        gateway_name=settings.GATEWAY_NAME,
    )

    # Initialize database connection pool
    await db_pool.connect()

    yield

    # Cleanup: close database pool
    await db_pool.disconnect()
    logger.info("gateway_shutting_down")


# Create FastAPI app
app = FastAPI(
    title=f"O.A.S.I.S. {settings.GATEWAY_NAME}",
    description="Log ingestion gateway with API key authentication and rate limiting",
    version="0.1.0",
    lifespan=lifespan,
)

# Set up rate limiter
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

# Set up middleware
setup_middleware(app)

# Include routers
app.include_router(health.router, tags=["Health"])
app.include_router(ingest.router, prefix="/api/v1", tags=["Ingestion"])
app.include_router(agents.router, prefix="/api/v1", tags=["Agents"])
app.include_router(syslog.router, prefix="/syslog", tags=["Syslog"])


if __name__ == "__main__":
    import uvicorn
    import os

    # TLS/HTTPS configuration
    ssl_certfile = settings.MTLS_CERT_PATH if os.path.exists(settings.MTLS_CERT_PATH) else None
    ssl_keyfile = settings.MTLS_KEY_PATH if os.path.exists(settings.MTLS_KEY_PATH) else None

    if ssl_certfile and ssl_keyfile:
        logger.info(
            "gateway_starting_https",
            cert_path=ssl_certfile,
            gateway_type=settings.GATEWAY_TYPE,
        )
        uvicorn.run(
            "src.main:app",
            host="0.0.0.0",
            port=8000,
            log_level=settings.LOG_LEVEL.lower(),
            access_log=True,
            ssl_certfile=ssl_certfile,
            ssl_keyfile=ssl_keyfile,
        )
    else:
        logger.warning(
            "gateway_starting_http_no_certs",
            cert_path=settings.MTLS_CERT_PATH,
            key_path=settings.MTLS_KEY_PATH,
        )
        uvicorn.run(
            "src.main:app",
            host="0.0.0.0",
            port=8000,
            log_level=settings.LOG_LEVEL.lower(),
            access_log=True,
        )
