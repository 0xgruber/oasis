"""
Docker client for querying service status from Docker daemon.
"""

import structlog
from datetime import datetime, timezone
from typing import Any

import docker
from docker.errors import DockerException

logger = structlog.get_logger(__name__)


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

            # Get network names
            networks = list(container.attrs.get("NetworkSettings", {}).get("Networks", {}).keys())

            # Format service name for display (capitalize words, remove hyphens)
            display_name = service_name.replace("-", " ").title()

            services.append(
                {
                    "name": display_name,
                    "container": container.name,
                    "status": health_status,
                    "state": state,
                    "uptime_seconds": uptime_seconds,
                    "networks": networks,
                }
            )

        logger.info("retrieved_service_status", service_count=len(services))

        return {"services": services}

    except DockerException as e:
        logger.error("docker_connection_failed", error=str(e))
        raise
