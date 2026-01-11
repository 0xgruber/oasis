"""
HTTP/JSON log ingestion endpoint
"""

from typing import List, Dict, Any
import ssl
import os
from datetime import datetime

import structlog
from fastapi import APIRouter, Request, Depends, HTTPException, status
from pydantic import BaseModel, Field
import httpx

from src.auth import validate_tenant_api_key
from src.config import settings

logger = structlog.get_logger()

router = APIRouter()


class LogEntry(BaseModel):
    """Single log entry model"""

    timestamp: str
    message: str
    severity: str = "informational"
    source: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class LogBatch(BaseModel):
    """Batch of log entries"""

    logs: List[LogEntry] = Field(..., max_length=settings.MAX_BATCH_SIZE)


class IngestResponse(BaseModel):
    """Ingestion response model"""

    accepted: int
    rejected: int
    tenant_id: str


async def _forward_to_ingestion_service(
    tenant_id: str, tenant_name: str, batch: LogBatch
) -> IngestResponse:
    """Helper to forward logs to ingestion service"""
    try:
        # Create SSL context for mTLS
        ssl_context = None
        if all(
            [
                os.path.exists(settings.MTLS_CERT_PATH),
                os.path.exists(settings.MTLS_KEY_PATH),
                os.path.exists(settings.MTLS_CA_PATH),
            ]
        ):
            ssl_context = ssl.create_default_context(
                purpose=ssl.Purpose.SERVER_AUTH,
                cafile=settings.MTLS_CA_PATH,
            )
            ssl_context.load_cert_chain(
                certfile=settings.MTLS_CERT_PATH,
                keyfile=settings.MTLS_KEY_PATH,
            )
            ssl_context.check_hostname = True
            ssl_context.verify_mode = ssl.CERT_REQUIRED

            ingestion_url = settings.INGESTION_SERVICE_URL
            logger.debug(
                "using_mtls_for_ingestion",
                url=ingestion_url,
                tenant_id=tenant_id,
            )
        else:
            ingestion_url = settings.INGESTION_SERVICE_URL.replace("https://", "http://")
            logger.warning(
                "mtls_certs_not_found_using_http",
                cert_path=settings.MTLS_CERT_PATH,
                tenant_id=tenant_id,
            )

        # Forward to ingestion service
        async with httpx.AsyncClient(verify=ssl_context or False) as client:
            response = await client.post(
                f"{ingestion_url}/ingest",
                json={
                    "tenant_id": tenant_id,
                    "logs": [log.model_dump() for log in batch.logs],
                },
                timeout=30.0,
            )

            if response.status_code == 202:
                logger.info(
                    "ingestion_forwarded_success",
                    tenant_id=tenant_id,
                    log_count=len(batch.logs),
                )
                return IngestResponse(
                    accepted=len(batch.logs),
                    rejected=0,
                    tenant_id=tenant_id,
                )
            else:
                logger.error(
                    "ingestion_forwarding_failed",
                    tenant_id=tenant_id,
                    status_code=response.status_code,
                    error=response.text,
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to forward logs to ingestion service",
                )

    except httpx.RequestError as e:
        logger.error(
            "ingestion_service_unreachable",
            tenant_id=tenant_id,
            error=str(e),
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Ingestion service unavailable",
        )


@router.post("/ingest", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
async def ingest_logs(
    request: Request,
    tenant_info: dict = Depends(validate_tenant_api_key),
) -> IngestResponse:
    """
    Ingest logs from Fluent Bit agents in native format

    Accepts Fluent Bit native format: [{"date": timestamp, "message": "...", ...}]

    This endpoint is used by:
    - Host agents (collecting local system logs)
    - Collector agents (aggregating syslog from network devices)

    Args:
        request: FastAPI request object
        tenant_info: Validated tenant information from API key

    Returns:
        Ingestion response with accepted/rejected counts
    """
    tenant_id = request.state.tenant_id
    tenant_name = request.state.tenant_name

    # Parse raw body as JSON (Fluent Bit sends array of objects)
    raw_logs = await request.json()

    if not isinstance(raw_logs, list):
        raise HTTPException(
            status_code=400, detail="Expected Fluent Bit format: array of log entries"
        )

    logger.info(
        "fluentbit_ingestion_request_received",
        tenant_id=tenant_id,
        tenant_name=tenant_name,
        log_count=len(raw_logs),
    )

    # Transform Fluent Bit format to LogEntry format
    logs = []
    for entry in raw_logs:
        # Extract timestamp (Fluent Bit uses 'date' field with epoch seconds)
        timestamp = entry.get("date", "")
        if isinstance(timestamp, (int, float)):
            timestamp = datetime.fromtimestamp(timestamp).isoformat()

        # Extract message field (try multiple common field names)
        message = entry.get("message") or entry.get("log") or str(entry)

        # Extract source (priority: source > systemd_unit > _HOSTNAME > default)
        source = (
            entry.get("source")
            or entry.get("systemd_unit")
            or entry.get("_HOSTNAME")
            or "fluent-bit"
        )

        # Create metadata from all other fields
        metadata = {
            k: v
            for k, v in entry.items()
            if k not in ["date", "message", "log", "source", "timestamp", "severity"]
        }

        logs.append(
            LogEntry(
                timestamp=timestamp,
                message=message,
                severity=entry.get("severity", "informational"),
                source=source,
                metadata=metadata,
            )
        )

    # Create batch and forward to ingestion service
    batch = LogBatch(logs=logs)

    # TODO: Implement rate limiting based on tenant EPS limit
    return await _forward_to_ingestion_service(tenant_id, tenant_name, batch)
