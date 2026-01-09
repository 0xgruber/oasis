"""
Health check endpoints
"""

from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter()


class HealthResponse(BaseModel):
    """Health check response model"""

    status: str
    service: str
    version: str


@router.get("/health", response_model=HealthResponse, status_code=status.HTTP_200_OK)
async def health_check() -> HealthResponse:
    """
    Health check endpoint for container health checks

    Returns:
        Health status information
    """
    return HealthResponse(
        status="healthy",
        service="internal-gateway",
        version="0.1.0",
    )


@router.get("/ready", response_model=HealthResponse, status_code=status.HTTP_200_OK)
async def readiness_check() -> HealthResponse:
    """
    Readiness check endpoint for Kubernetes/orchestration

    Returns:
        Readiness status information
    """
    # TODO: Check database connectivity
    return HealthResponse(
        status="ready",
        service="internal-gateway",
        version="0.1.0",
    )
