"""
O.A.S.I.S. Metrics Service
Real-time metrics aggregation and caching
"""

import structlog
from typing import Optional
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
    get_agents_list,
    get_agent_by_id,
    get_agent_status_breakdown,
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


@app.get("/metrics/agents")
async def list_agents(
    tenant_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
):
    """
    List all agents with computed status (with pagination and filtering)

    Query Parameters:
        tenant_id: Optional tenant UUID filter
        status: Optional status filter (online, offline, dead, unknown)
        limit: Maximum number of results (default: 100, max: 1000)
        offset: Number of results to skip (default: 0)

    Returns:
        Object with:
        - agents: List of agent objects
        - total: Total count (before pagination)
        - limit: Requested limit
        - offset: Requested offset

    Example:
        {
            "agents": [...],
            "total": 25,
            "limit": 100,
            "offset": 0
        }
    """
    # Validate limit
    if limit > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Limit cannot exceed 1000",
        )

    if limit < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Limit must be at least 1",
        )

    # Validate status filter
    valid_statuses = ["online", "offline", "dead", "unknown"]
    if status and status not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}",
        )

    try:
        result = await get_agents_list(
            tenant_id=tenant_id, status_filter=status, limit=limit, offset=offset
        )
        return result
    except Exception as e:
        logger.error(
            "list_agents_endpoint_failed", tenant_id=tenant_id, status=status, error=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agents list: {str(e)}",
        )


@app.get("/metrics/agents/status")
async def agent_status_breakdown(tenant_id: Optional[str] = None):
    """
    Get agent status breakdown counts

    Query Parameters:
        tenant_id: Optional tenant UUID filter

    Returns:
        Dictionary with counts by status:
        - online: Number of online agents
        - offline: Number of offline agents
        - dead: Number of dead agents
        - unknown: Number of agents with unknown status
        - total: Total number of agents

    Example:
        {
            "online": 5,
            "offline": 2,
            "dead": 1,
            "unknown": 0,
            "total": 8
        }
    """
    try:
        breakdown = await get_agent_status_breakdown(tenant_id)
        return breakdown
    except Exception as e:
        logger.error("agent_status_breakdown_endpoint_failed", tenant_id=tenant_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agent status breakdown: {str(e)}",
        )


@app.get("/metrics/agents/{agent_id}")
async def get_agent(agent_id: str):
    """
    Get a single agent by ID with computed status

    Path Parameters:
        agent_id: Agent UUID

    Returns:
        Agent object with all fields including created_at and updated_at

    Example:
        {
            "agent_id": "660e8400-e29b-41d4-a716-446655440000",
            "hostname": "web-01",
            "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
            "last_seen": "2026-01-11T22:30:00+00:00",
            "status": "online",
            "os_type": "Linux",
            "os_version": "Ubuntu 24.04",
            "agent_type": "fluent-bit",
            "is_active": true,
            "created_at": "2026-01-10T10:00:00+00:00",
            "updated_at": "2026-01-11T22:30:00+00:00"
        }
    """
    try:
        agent = await get_agent_by_id(agent_id)
        if not agent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Agent {agent_id} not found",
            )
        return agent
    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_agent_endpoint_failed", agent_id=agent_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch agent: {str(e)}",
        )
