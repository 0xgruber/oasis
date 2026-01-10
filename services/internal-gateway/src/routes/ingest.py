"""
HTTP/JSON log ingestion endpoint
"""

from typing import List, Dict, Any
import ssl
import os

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


@router.post("/ingest", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
async def ingest_logs(
    batch: LogBatch,
    request: Request,
    tenant_info: dict = Depends(validate_tenant_api_key),
) -> IngestResponse:
    """
    Ingest a batch of logs from authenticated tenant

    Args:
        batch: Batch of log entries
        request: FastAPI request object
        tenant_info: Validated tenant information from API key

    Returns:
        Ingestion response with accepted/rejected counts
    """
    tenant_id = request.state.tenant_id
    tenant_name = request.state.tenant_name

    logger.info(
        "ingestion_request_received",
        tenant_id=tenant_id,
        tenant_name=tenant_name,
        log_count=len(batch.logs),
    )

    # TODO: Implement rate limiting based on tenant EPS limit

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
