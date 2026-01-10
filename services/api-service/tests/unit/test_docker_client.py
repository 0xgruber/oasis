"""
Unit tests for docker_client module.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timezone
from docker.errors import DockerException

from src.docker_client import get_service_status


@pytest.fixture
def mock_container_healthy():
    """Mock a healthy running container"""
    container = Mock()
    container.name = "oasis-api-service"
    container.status = "running"
    container.labels = {
        "com.docker.compose.project": "oasis",
        "com.docker.compose.service": "api-service",
    }
    container.attrs = {
        "State": {"Health": {"Status": "healthy"}, "StartedAt": "2026-01-10T00:00:00.000000000Z"},
        "NetworkSettings": {"Networks": {"backend-network": {}}},
    }
    return container


@pytest.fixture
def mock_container_unhealthy():
    """Mock an unhealthy container"""
    container = Mock()
    container.name = "oasis-ingestion-service"
    container.status = "running"
    container.labels = {
        "com.docker.compose.project": "oasis",
        "com.docker.compose.service": "ingestion-service",
    }
    container.attrs = {
        "State": {"Health": {"Status": "unhealthy"}, "StartedAt": "2026-01-10T00:00:00.000000000Z"},
        "NetworkSettings": {"Networks": {"backend-network": {}}},
    }
    return container


@pytest.fixture
def mock_container_stopped():
    """Mock a stopped container"""
    container = Mock()
    container.name = "oasis-clickhouse"
    container.status = "exited"
    container.labels = {
        "com.docker.compose.project": "oasis",
        "com.docker.compose.service": "clickhouse",
    }
    container.attrs = {"State": {"StartedAt": ""}, "NetworkSettings": {"Networks": {}}}
    return container


@pytest.fixture
def mock_container_no_health():
    """Mock a container without health check"""
    container = Mock()
    container.name = "oasis-postgresql"
    container.status = "running"
    container.labels = {
        "com.docker.compose.project": "oasis",
        "com.docker.compose.service": "postgresql",
    }
    container.attrs = {
        "State": {"StartedAt": "2026-01-10T00:00:00.000000000Z"},
        "NetworkSettings": {"Networks": {"backend-network": {}}},
    }
    return container


@pytest.fixture
def mock_container_multi_network():
    """Mock a container in multiple networks"""
    container = Mock()
    container.name = "oasis-internal-gateway"
    container.status = "running"
    container.labels = {
        "com.docker.compose.project": "oasis",
        "com.docker.compose.service": "internal-gateway",
    }
    container.attrs = {
        "State": {"Health": {"Status": "healthy"}, "StartedAt": "2026-01-10T00:00:00.000000000Z"},
        "NetworkSettings": {"Networks": {"internal-network": {}, "backend-network": {}}},
    }
    return container


class TestGetServiceStatus:
    """Tests for get_service_status function"""

    @patch("src.docker_client.docker.from_env")
    def test_single_healthy_container(self, mock_docker_from_env, mock_container_healthy):
        """Test querying a single healthy container"""
        mock_client = Mock()
        mock_client.containers.list.return_value = [mock_container_healthy]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert "services" in result
        assert len(result["services"]) == 1

        service = result["services"][0]
        assert service["name"] == "Api Service"
        assert service["container"] == "oasis-api-service"
        assert service["status"] == "healthy"
        assert service["state"] == "running"
        assert service["uptime_seconds"] > 0
        assert "backend-network" in service["networks"]

    @patch("src.docker_client.docker.from_env")
    def test_multiple_containers(
        self,
        mock_docker_from_env,
        mock_container_healthy,
        mock_container_unhealthy,
        mock_container_stopped,
    ):
        """Test querying multiple containers with different states"""
        mock_client = Mock()
        mock_client.containers.list.return_value = [
            mock_container_healthy,
            mock_container_unhealthy,
            mock_container_stopped,
        ]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert len(result["services"]) == 3

        # Check healthy container
        healthy = next(s for s in result["services"] if s["container"] == "oasis-api-service")
        assert healthy["status"] == "healthy"
        assert healthy["state"] == "running"

        # Check unhealthy container
        unhealthy = next(
            s for s in result["services"] if s["container"] == "oasis-ingestion-service"
        )
        assert unhealthy["status"] == "unhealthy"
        assert unhealthy["state"] == "running"

        # Check stopped container
        stopped = next(s for s in result["services"] if s["container"] == "oasis-clickhouse")
        assert stopped["state"] == "exited"
        assert stopped["uptime_seconds"] == 0

    @patch("src.docker_client.docker.from_env")
    def test_container_without_health_check(self, mock_docker_from_env, mock_container_no_health):
        """Test container without health check configured"""
        mock_client = Mock()
        mock_client.containers.list.return_value = [mock_container_no_health]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert len(result["services"]) == 1
        service = result["services"][0]
        assert service["status"] == "none"
        assert service["state"] == "running"

    @patch("src.docker_client.docker.from_env")
    def test_multi_network_container(self, mock_docker_from_env, mock_container_multi_network):
        """Test container connected to multiple networks"""
        mock_client = Mock()
        mock_client.containers.list.return_value = [mock_container_multi_network]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert len(result["services"]) == 1
        service = result["services"][0]
        assert len(service["networks"]) == 2
        assert "internal-network" in service["networks"]
        assert "backend-network" in service["networks"]

    @patch("src.docker_client.docker.from_env")
    def test_no_containers(self, mock_docker_from_env):
        """Test when no OASIS containers are found"""
        mock_client = Mock()
        mock_client.containers.list.return_value = []
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert "services" in result
        assert len(result["services"]) == 0

    @patch("src.docker_client.docker.from_env")
    def test_docker_connection_failure(self, mock_docker_from_env):
        """Test handling Docker daemon connection failure"""
        mock_docker_from_env.side_effect = DockerException("Cannot connect to Docker daemon")

        with pytest.raises(DockerException):
            get_service_status()

    @patch("src.docker_client.docker.from_env")
    def test_service_name_formatting(self, mock_docker_from_env):
        """Test service name is properly formatted for display"""
        container = Mock()
        container.name = "oasis-test-service"
        container.status = "running"
        container.labels = {
            "com.docker.compose.project": "oasis",
            "com.docker.compose.service": "test-service",
        }
        container.attrs = {
            "State": {
                "Health": {"Status": "healthy"},
                "StartedAt": "2026-01-10T00:00:00.000000000Z",
            },
            "NetworkSettings": {"Networks": {}},
        }

        mock_client = Mock()
        mock_client.containers.list.return_value = [container]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert result["services"][0]["name"] == "Test Service"

    @patch("src.docker_client.docker.from_env")
    @patch("src.docker_client.datetime")
    def test_uptime_calculation(self, mock_datetime, mock_docker_from_env):
        """Test uptime is correctly calculated"""
        # Mock current time
        mock_now = datetime(2026, 1, 10, 2, 0, 0, tzinfo=timezone.utc)
        mock_datetime.now.return_value = mock_now
        mock_datetime.fromisoformat = datetime.fromisoformat

        container = Mock()
        container.name = "oasis-api-service"
        container.status = "running"
        container.labels = {
            "com.docker.compose.project": "oasis",
            "com.docker.compose.service": "api-service",
        }
        # Started 2 hours ago
        container.attrs = {
            "State": {
                "Health": {"Status": "healthy"},
                "StartedAt": "2026-01-10T00:00:00.000000000Z",
            },
            "NetworkSettings": {"Networks": {}},
        }

        mock_client = Mock()
        mock_client.containers.list.return_value = [container]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        assert result["services"][0]["uptime_seconds"] == 7200  # 2 hours

    @patch("src.docker_client.docker.from_env")
    def test_container_label_filters(self, mock_docker_from_env):
        """Test that only OASIS project containers are queried"""
        mock_client = Mock()
        mock_client.containers.list.return_value = []
        mock_docker_from_env.return_value = mock_client

        get_service_status()

        # Verify the filter was applied
        mock_client.containers.list.assert_called_once_with(
            all=True, filters={"label": "com.docker.compose.project=oasis"}
        )

    @patch("src.docker_client.docker.from_env")
    def test_container_missing_service_label(self, mock_docker_from_env):
        """Test handling container without service label"""
        container = Mock()
        container.name = "oasis-unknown"
        container.status = "running"
        container.labels = {
            "com.docker.compose.project": "oasis"
            # Missing com.docker.compose.service
        }
        container.attrs = {
            "State": {"StartedAt": "2026-01-10T00:00:00.000000000Z"},
            "NetworkSettings": {"Networks": {}},
        }

        mock_client = Mock()
        mock_client.containers.list.return_value = [container]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        # Should use "unknown" as service name
        assert result["services"][0]["name"] == "Unknown"

    @patch("src.docker_client.docker.from_env")
    def test_invalid_started_at_timestamp(self, mock_docker_from_env):
        """Test handling invalid StartedAt timestamp"""
        container = Mock()
        container.name = "oasis-api-service"
        container.status = "running"
        container.labels = {
            "com.docker.compose.project": "oasis",
            "com.docker.compose.service": "api-service",
        }
        container.attrs = {
            "State": {"Health": {"Status": "healthy"}, "StartedAt": "invalid-timestamp"},
            "NetworkSettings": {"Networks": {}},
        }

        mock_client = Mock()
        mock_client.containers.list.return_value = [container]
        mock_docker_from_env.return_value = mock_client

        result = get_service_status()

        # Should not raise exception, uptime should be 0
        assert result["services"][0]["uptime_seconds"] == 0
