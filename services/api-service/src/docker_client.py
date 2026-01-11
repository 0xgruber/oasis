"""
Docker client for querying service status from Docker daemon.
"""

import structlog
from datetime import datetime, timezone
from typing import Any

import docker
from docker.errors import DockerException

logger = structlog.get_logger(__name__)

# Service descriptions for each OASIS component
SERVICE_DESCRIPTIONS = {
    "api-service": "Query and management API with JWT authentication. Provides endpoints for log queries, tenant management, and service monitoring.",
    "soc-portal": "Security Operations Center web interface. React-based dashboard for log analysis, alerting, and system administration.",
    "ingestion-service": "Log ingestion and normalization service. Accepts logs via syslog/HTTP, normalizes to OCSF format, and stores in ClickHouse.",
    "internal-gateway": "Internal network gateway for corporate log sources. Handles authentication, rate limiting, and routing to ingestion service.",
    "external-gateway": "DMZ gateway for internet-facing log sources. First line of defense with strict rate limiting and API key authentication.",
    "metrics-service": "Real-time metrics aggregation service with Redis caching. Calculates system-wide, per-tenant, and per-agent metrics from ClickHouse and PostgreSQL.",
    "postgresql": "Relational database for tenant metadata, user accounts, API keys, and configuration data. Multi-tenant schema isolation.",
    "clickhouse": "Columnar database for high-performance log storage and analytics. Table-per-tenant architecture for isolation and scalability.",
    "qdrant": "Vector database for AI-powered semantic search and similarity analysis. Enables natural language log queries (Phase 3).",
    "redis": "In-memory cache for metrics data. Stores pre-calculated metrics with TTL to reduce database load and improve API response times.",
}


def get_service_status() -> dict[str, Any]:
    """
    Query Docker daemon for all OASIS containers and return their status.

    Returns:
        dict: Service status information with the following structure:
            {
                "services": [
                    {
                        "name": "Internal Gateway",
                        "container": "oasis-internal-gateway",
                        "status": "healthy",  # healthy/unhealthy/starting/none
                        "state": "running",    # running/stopped/restarting/exited
                        "uptime_seconds": 7200,
                        "networks": ["internal-network", "backend-network"]
                    },
                    ...
                ]
            }

    Raises:
        DockerException: If unable to connect to Docker daemon
    """
    try:
        client = docker.from_env()

        # Get all containers with the oasis project label
        containers = client.containers.list(
            all=True,  # Include stopped containers
            filters={"label": "com.docker.compose.project=oasis"},
        )

        services = []

        for container in containers:
            # Extract service name from label or container name
            service_name = container.labels.get("com.docker.compose.service", "unknown")

            # Get health status from Docker health check
            health_status = "none"
            if "Health" in container.attrs.get("State", {}):
                health_data = container.attrs["State"]["Health"]
                health_status = health_data.get("Status", "none")

            # Get container state
            state = container.status  # running/stopped/restarting/exited/etc

            # Calculate uptime
            uptime_seconds = 0
            if state == "running":
                started_at_str = container.attrs["State"].get("StartedAt", "")
                if started_at_str:
                    try:
                        # Parse ISO 8601 format: 2026-01-10T00:00:00.000000000Z
                        started_at = datetime.fromisoformat(
                            started_at_str.replace("Z", "+00:00").split(".")[0] + "+00:00"
                        )
                        now = datetime.now(timezone.utc)
                        uptime_seconds = int((now - started_at).total_seconds())
                    except (ValueError, AttributeError) as e:
                        logger.warning(
                            "failed_to_parse_uptime",
                            container=container.name,
                            started_at=started_at_str,
                            error=str(e),
                        )

            # Get network names and details
            networks = list(container.attrs.get("NetworkSettings", {}).get("Networks", {}).keys())

            # Get network details with IP addresses
            network_details = []
            for net_name, net_data in (
                container.attrs.get("NetworkSettings", {}).get("Networks", {}).items()
            ):
                network_details.append(
                    {
                        "name": net_name,
                        "ip_address": net_data.get("IPAddress", ""),
                        "gateway": net_data.get("Gateway", ""),
                    }
                )

            # Get port mappings
            port_bindings = []
            ports = container.attrs.get("NetworkSettings", {}).get("Ports", {})
            for internal_port, bindings in ports.items() if ports else []:
                if bindings:
                    for binding in bindings:
                        port_bindings.append(
                            {
                                "internal": internal_port,
                                "external": f"{binding.get('HostIp', '0.0.0.0')}:{binding.get('HostPort', '')}",
                            }
                        )
                else:
                    # Port exposed but not bound
                    port_bindings.append({"internal": internal_port, "external": None})

            # Get volume mounts
            mounts = []
            for mount in container.attrs.get("Mounts", []):
                mounts.append(
                    {
                        "type": mount.get("Type", ""),
                        "source": mount.get("Source", ""),
                        "destination": mount.get("Destination", ""),
                        "mode": mount.get("Mode", ""),
                    }
                )

            # Get container image
            image = container.attrs.get("Config", {}).get("Image", "")

            # Get environment variables (filter sensitive ones)
            env_vars = []
            for env in container.attrs.get("Config", {}).get("Env", []):
                # Skip sensitive env vars
                if any(
                    sensitive in env.upper() for sensitive in ["PASSWORD", "SECRET", "TOKEN", "KEY"]
                ):
                    key = env.split("=")[0]
                    env_vars.append(f"{key}=***")
                else:
                    env_vars.append(env)

            # Format service name for display (capitalize words, remove hyphens)
            display_name = service_name.replace("-", " ").title()
            # Fix acronyms to uppercase
            display_name = display_name.replace("Api", "API").replace("Soc", "SOC")

            # Get service description
            description = SERVICE_DESCRIPTIONS.get(service_name, "No description available")

            services.append(
                {
                    "name": display_name,
                    "container": container.name,
                    "status": health_status,
                    "state": state,
                    "uptime_seconds": uptime_seconds,
                    "networks": networks,
                    "description": description,
                    "network_details": network_details,
                    "port_bindings": port_bindings,
                    "mounts": mounts,
                    "image": image,
                    "env_vars": env_vars,
                }
            )

        logger.info("retrieved_service_status", service_count=len(services))

        return {"services": services}

    except DockerException as e:
        logger.error("docker_connection_failed", error=str(e))
        raise
