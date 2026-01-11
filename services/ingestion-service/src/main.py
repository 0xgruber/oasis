"""
O.A.S.I.S. Ingestion Service
Normalizes logs and stores them in ClickHouse
"""

from typing import List, Dict, Any
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from src.config import settings
from src.clickhouse import ch_client
from src.normalizer import OCSFNormalizer
from src.database import db_pool

logger = structlog.get_logger()

normalizer = OCSFNormalizer()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan"""
    logger.info("ingestion_service_starting")
    ch_client.connect()
    await db_pool.connect()
    yield
    ch_client.disconnect()
    await db_pool.disconnect()
    logger.info("ingestion_service_shutting_down")


app = FastAPI(
    title="O.A.S.I.S. Ingestion Service",
    description="Log normalization and storage service",
    version="0.1.0",
    lifespan=lifespan,
)


class RawLog(BaseModel):
    """Raw log entry from gateway"""

    timestamp: str
    message: str
    severity: str = "informational"
    source: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class IngestRequest(BaseModel):
    """Ingestion request from gateway"""

    tenant_id: str
    logs: List[RawLog] = Field(..., max_length=settings.BATCH_SIZE)


class IngestResponse(BaseModel):
    """Ingestion response"""

    accepted: int
    rejected: int


class HealthResponse(BaseModel):
    """Health check response"""

    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        service="ingestion-service",
        version="0.1.0",
    )


@app.post("/ingest", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
async def ingest_logs(request: IngestRequest) -> IngestResponse:
    """
    Ingest and store logs from gateway

    Args:
        request: Ingestion request with tenant_id and logs

    Returns:
        Ingestion response with counts
    """
    tenant_id = request.tenant_id
    log_count = len(request.logs)

    logger.info(
        "ingestion_request_received",
        tenant_id=tenant_id,
        log_count=log_count,
    )

    try:
        # Ensure tenant table exists (will check cache in production)
        # TODO: Add tenant lookup from PostgreSQL for retention_days
        ch_client.ensure_tenant_table(tenant_id, retention_days=90)

        # Extract unique hostnames from logs for heartbeat updates
        hostnames = set()
        for log in request.logs:
            # Check metadata for hostname fields (common keys from Fluent Bit)
            hostname = (
                log.metadata.get("_HOSTNAME")
                or log.metadata.get("hostname")
                or log.metadata.get("host")
            )
            if hostname:
                hostnames.add(hostname)

        # Normalize logs to OCSF
        normalized_logs = []
        for log in request.logs:
            try:
                normalized = normalizer.normalize(log.model_dump())
                normalized_logs.append(normalized)
            except Exception as e:
                logger.error(
                    "log_normalization_error",
                    tenant_id=tenant_id,
                    error=str(e),
                    log=log.model_dump(),
                )
                # Continue with other logs even if one fails

        if not normalized_logs:
            return IngestResponse(accepted=0, rejected=log_count)

        # Insert into ClickHouse
        inserted = ch_client.insert_logs(tenant_id, normalized_logs)

        # Update agent heartbeats (async, don't wait for completion)
        if hostnames:
            for hostname in hostnames:
                try:
                    await db_pool.update_agent_heartbeat(tenant_id, hostname)
                except Exception as e:
                    # Log but don't fail ingestion if heartbeat fails
                    logger.error(
                        "heartbeat_update_failed",
                        tenant_id=tenant_id,
                        hostname=hostname,
                        error=str(e),
                    )

        logger.info(
            "ingestion_completed",
            tenant_id=tenant_id,
            accepted=inserted,
            rejected=log_count - inserted,
            hostnames=list(hostnames),
        )

        return IngestResponse(
            accepted=inserted,
            rejected=log_count - inserted,
        )

    except Exception as e:
        logger.error(
            "ingestion_failed",
            tenant_id=tenant_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ingestion failed: {str(e)}",
        )


if __name__ == "__main__":
    import uvicorn
    import os

    # TLS/HTTPS configuration with mTLS
    ssl_certfile = settings.MTLS_CERT_PATH if os.path.exists(settings.MTLS_CERT_PATH) else None
    ssl_keyfile = settings.MTLS_KEY_PATH if os.path.exists(settings.MTLS_KEY_PATH) else None
    ssl_ca_certs = settings.MTLS_CA_PATH if os.path.exists(settings.MTLS_CA_PATH) else None

    if ssl_certfile and ssl_keyfile and ssl_ca_certs:
        logger.info(
            "ingestion_starting_https_mtls",
            cert_path=ssl_certfile,
            ca_path=ssl_ca_certs,
        )
        uvicorn.run(
            "src.main:app",
            host="0.0.0.0",
            port=8080,
            log_level=settings.LOG_LEVEL.lower(),
            ssl_certfile=ssl_certfile,
            ssl_keyfile=ssl_keyfile,
            ssl_ca_certs=ssl_ca_certs,
            ssl_cert_reqs=2,  # ssl.CERT_REQUIRED - require client certificate
        )
    else:
        logger.warning(
            "ingestion_starting_http_no_certs",
            cert_path=ssl_certfile,
            key_path=ssl_keyfile,
            ca_path=ssl_ca_certs,
        )
        uvicorn.run(
            "src.main:app",
            host="0.0.0.0",
            port=8080,
            log_level=settings.LOG_LEVEL.lower(),
        )
