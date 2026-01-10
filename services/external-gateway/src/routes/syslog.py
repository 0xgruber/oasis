"""
Syslog listener endpoint (placeholder for Phase 1B)
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/status")
async def syslog_status() -> dict:
    """
    Syslog service status endpoint

    Note: Syslog UDP/TCP/TLS listeners will be implemented in Phase 1B
    """
    return {
        "status": "not_implemented",
        "message": "Syslog listeners will be implemented in Phase 1B",
        "supported_protocols": ["udp/514", "tcp/514", "tls/6514"],
        "supported_formats": ["RFC3164", "RFC5424"],
    }
