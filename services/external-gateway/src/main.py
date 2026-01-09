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
from src.routes import health, ingest, syslog

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler"""
    logger.info(
        "gateway_starting",
        gateway_type=settings.GATEWAY_TYPE,
        gateway_name=settings.GATEWAY_NAME,
    )
    yield
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
app.include_router(syslog.router, prefix="/syslog", tags=["Syslog"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        log_level=settings.LOG_LEVEL.lower(),
        access_log=True,
    )
