"""
Agent Registration Endpoint
Allows Vector agents to register and update their status
"""

from typing import Optional, Dict, Any
import platform

import structlog
from fastapi import APIRouter, Request, Depends, HTTPException, status
from pydantic import BaseModel, Field

from src.auth import validate_tenant_api_key
from src.database import db_pool

logger = structlog.get_logger()

router = APIRouter()


class AgentRegistration(BaseModel):
    """Agent registration request model"""

    hostname: str = Field(..., description="Hostname of the machine running the agent")
    agent_type: str = Field(default="vector", description="Type of agent (default: vector)")
    os_type: str = Field(..., description="Operating system type (e.g., linux, macos, windows)")
    os_version: Optional[str] = Field(None, description="OS version string")
    agent_version: Optional[str] = Field(None, description="Agent/Vector version")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")


class AgentRegistrationResponse(BaseModel):
    """Agent registration response model"""

    agent_id: str = Field(..., description="UUID of the registered agent")
    status: str = Field(..., description="Registration status")
    message: str = Field(..., description="Human-readable message")


@router.post(
    "/agents/register",
    response_model=AgentRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_agent(
    agent: AgentRegistration,
    request: Request,
    tenant_info: dict = Depends(validate_tenant_api_key),
) -> AgentRegistrationResponse:
    """
    Register or update a Vector agent for the authenticated tenant

    This endpoint allows Vector agents to register themselves with O.A.S.I.S.
    If the agent (identified by tenant_id + hostname) already exists, its
    last_seen timestamp and metadata will be updated.

    Args:
        agent: Agent registration information
        request: FastAPI request object
        tenant_info: Validated tenant information from API key

    Returns:
        Agent registration response with agent_id and status
    """
    tenant_id = request.state.tenant_id
    tenant_name = request.state.tenant_name

    # Get client IP address
    client_ip = request.client.host if request.client else None

    logger.info(
        "agent_registration_request",
        tenant_id=tenant_id,
        tenant_name=tenant_name,
        hostname=agent.hostname,
        agent_type=agent.agent_type,
        os_type=agent.os_type,
        client_ip=client_ip,
    )

    try:
        # Upsert agent record using the database function
        agent_id = await db_pool.upsert_agent(
            tenant_id=tenant_id,
            hostname=agent.hostname,
            agent_type=agent.agent_type,
            os_type=agent.os_type,
            os_version=agent.os_version,
            agent_version=agent.agent_version,
            ip_address=client_ip,
            metadata=agent.metadata,
        )

        logger.info(
            "agent_registered_successfully",
            tenant_id=tenant_id,
            agent_id=agent_id,
            hostname=agent.hostname,
        )

        return AgentRegistrationResponse(
            agent_id=str(agent_id),
            status="registered",
            message=f"Agent '{agent.hostname}' registered successfully",
        )

    except Exception as e:
        logger.error(
            "agent_registration_failed",
            tenant_id=tenant_id,
            hostname=agent.hostname,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register agent: {str(e)}",
        )


@router.get("/agents", status_code=status.HTTP_200_OK)
async def list_agents(
    request: Request,
    tenant_info: dict = Depends(validate_tenant_api_key),
    active_only: bool = True,
) -> Dict[str, Any]:
    """
    List all agents for the authenticated tenant

    Args:
        request: FastAPI request object
        tenant_info: Validated tenant information from API key
        active_only: If True, only return agents seen in the last 15 minutes

    Returns:
        List of agents with their metadata
    """
    tenant_id = request.state.tenant_id

    try:
        agents = await db_pool.list_agents(tenant_id=tenant_id, active_only=active_only)

        logger.info(
            "agents_listed",
            tenant_id=tenant_id,
            agent_count=len(agents),
            active_only=active_only,
        )

        return {
            "tenant_id": tenant_id,
            "agent_count": len(agents),
            "agents": agents,
        }

    except Exception as e:
        logger.error(
            "agent_list_failed",
            tenant_id=tenant_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list agents: {str(e)}",
        )
