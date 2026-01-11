"""
O.A.S.I.S. Metrics Service
Real-time metrics aggregation and caching
"""

import structlog
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .cache import cache
from .metrics import (
    initialize_connections,
    close_connections,
    get_system_metrics,
    get_tenant_metrics,
    get_agent_metrics,
)

logger = structlog.get_logger()

app = FastAPI(
    title="O.A.S.I.S. Metrics Service",
    description="Real-time metrics aggregation and caching service",
    version="0.1.0",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Will be accessed by API service
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    """Initialize connections on startup"""
    await cache.connect()
    await initialize_connections()
    logger.info("metrics_service_started", port=8001)


@app.on_event("shutdown")
async def shutdown():
    """Close connections on shutdown"""
    await cache.disconnect()
    await close_connections()
    logger.info("metrics_service_stopped")


@app.get("/health")
async def health_check():
    """
    Health check endpoint

    Returns:
        Status message
    """
    return {"status": "healthy", "service": "metrics-service", "version": "0.1.0"}


@app.get("/metrics/system")
async def system_metrics():
    """
    Get system-wide metrics

    Returns:
        - total_logs: Total log count across all tenants
        - total_sources: Unique agent hostnames
        - ingestion_rate: Logs per second in last 5 minutes

    Example:
        {
            "total_logs": 3723,
            "total_sources": 5,
            "ingestion_rate": 0.13
        }
    """
    try:
        metrics = await get_system_metrics()
        return metrics
    except Exception as e:
        logger.error("system_metrics_endpoint_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch system metrics: {str(e)}",
        )


@app.get("/metrics/tenant/{tenant_id}")
async def tenant_metrics(tenant_id: str):
    """
    Get per-tenant metrics

    Args:
        tenant_id: Tenant UUID

    Returns:
        - tenant_id: Tenant UUID
        - logs_count: Total logs for this tenant
        - sources_count: Number of agents for this tenant
        - ingestion_rate: Logs per second in last 5 minutes

    Example:
        {
            "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
            "logs_count": 1500,
            "sources_count": 2,
            "ingestion_rate": 0.05
        }
    """
    try:
        metrics = await get_tenant_metrics(tenant_id)
        return metrics
    except Exception as e:
        logger.error("tenant_metrics_endpoint_failed", tenant_id=tenant_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch tenant metrics: {str(e)}",
        )


@app.get("/metrics/agent/{agent_id}")
async def agent_metrics(agent_id: str):
    """
    Get per-agent metrics

    Args:
        agent_id: Agent UUID

    Returns:
        - agent_id: Agent UUID
        - hostname: Agent hostname
        - tenant_id: Tenant UUID
        - logs_count: Total logs from this agent
        - last_seen: Last time agent was seen (ISO timestamp)
        - status: Agent status (active, inactive, etc.)

    Example:
        {
            "agent_id": "660e8400-e29b-41d4-a716-446655440000",
            "hostname": "web-server-01",
            "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
            "logs_count": 500,
            "last_seen": "2026-01-11T10:30:00",
            "status": "active"
        }
    """
    try:
        metrics = await get_agent_metrics(agent_id)
        return metrics
    except Exception as e:
        logger.error("agent_metrics_endpoint_failed", agent_id=agent_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agent metrics: {str(e)}",
        )


@app.post("/cache/clear")
async def clear_cache():
    """
    Clear all cached metrics (admin endpoint)

    Returns:
        Success message
    """
    try:
        # Clear all metrics cache keys
        await cache.clear_pattern("metrics:*")
        logger.info("cache_cleared")
        return {"status": "success", "message": "All metrics cache cleared"}
    except Exception as e:
        logger.error("cache_clear_failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to clear cache: {str(e)}",
        )


@app.post("/cache/clear/tenant/{tenant_id}")
async def clear_tenant_cache(tenant_id: str):
    """
    Clear cached metrics for a specific tenant

    Args:
        tenant_id: Tenant UUID

    Returns:
        Success message
    """
    try:
        await cache.delete(f"metrics:tenant:{tenant_id}")
        logger.info("tenant_cache_cleared", tenant_id=tenant_id)
        return {"status": "success", "message": f"Cache cleared for tenant {tenant_id}"}
    except Exception as e:
        logger.error("tenant_cache_clear_failed", tenant_id=tenant_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to clear tenant cache: {str(e)}",
        )
