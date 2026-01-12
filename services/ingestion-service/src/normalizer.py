"""
OCSF (Open Cybersecurity Schema Framework) normalization
"""

from typing import Dict, Any
from datetime import datetime
from dateutil import parser as date_parser
import structlog

logger = structlog.get_logger()


class OCSFNormalizer:
    """Normalize logs to OCSF format"""

    @staticmethod
    def normalize(raw_log: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize a raw log entry to OCSF format

        Args:
            raw_log: Raw log entry from gateway

        Returns:
            Normalized log with OCSF structure
        """
        try:
            # Parse timestamp
            timestamp_str = raw_log.get("timestamp")
            if timestamp_str:
                timestamp = date_parser.parse(timestamp_str)
            else:
                timestamp = datetime.utcnow()

            # Map severity to OCSF severity_id
            # severity_id 0: Unknown, 1: Informational, 2: Low, 3: Medium, 4: High, 5: Critical, 6: Fatal, 99: Other
            severity_map = {
                # severity_id 0: Unknown - for truly unknown severities
                "unknown": 0,
                # severity_id 1: Informational - trace, info, informational (no action needed)
                "trace": 1,
                "informational": 1,
                "info": 1,  # Common short form
                # severity_id 2: Low - debug level (developer information)
                "debug": 2,
                "notice": 2,
                "low": 2,
                # severity_id 3: Medium - warnings that need attention but not urgent
                "warn": 3,
                "warning": 3,
                "medium": 3,
                # severity_id 4: High - error conditions that require action
                "error": 4,
                "err": 4,
                "high": 4,
                # severity_id 5: Critical - critical conditions requiring immediate action
                "critical": 5,
                "crit": 5,
                "alert": 5,
                # severity_id 6: Fatal - fatal errors, too late to recover
                "fatal": 6,
                "emergency": 6,
                # severity_id 99: Other - severity is not mapped to standard levels
                "other": 99,
            }

            # Normalize severity string to lowercase for case-insensitive matching
            severity = raw_log.get("severity", "informational").lower()
            severity_id = severity_map.get(severity, 1)  # Default to Informational (1)

            # Build OCSF structure
            ocsf = {
                "class_uid": 3001,  # Generic log event
                "class_name": "Application Activity",
                "category_uid": 3,
                "category_name": "Application Activity",
                "activity_id": 1,
                "activity_name": "Log",
                "severity_id": severity_id,
                "severity": severity,
                "time": int(timestamp.timestamp() * 1000),  # milliseconds
                "message": raw_log.get("message", ""),
                "metadata": {
                    "version": "1.0.0",
                    "product": {
                        "name": raw_log.get("source", "unknown"),
                        "vendor_name": "O.A.S.I.S.",
                    },
                },
            }

            # Add custom metadata if present
            if "metadata" in raw_log:
                ocsf["metadata"]["custom"] = raw_log["metadata"]

            # Extract IPs if present in metadata
            source_ip = "0.0.0.0"
            dest_ip = "0.0.0.0"
            if isinstance(raw_log.get("metadata"), dict):
                source_ip = raw_log["metadata"].get("source_ip", "0.0.0.0")
                dest_ip = raw_log["metadata"].get("destination_ip", "0.0.0.0")

            return {
                "timestamp": timestamp,  # Return datetime object for ClickHouse
                "raw_log": str(raw_log),
                "message": raw_log.get("message", ""),  # Extract message
                "ocsf": ocsf,
                "source_ip": source_ip,
                "destination_ip": dest_ip,
                "severity_id": severity_id,
                "category_uid": 3,
                "class_uid": 3001,
                "activity_id": 1,
                "status_id": 1,  # Success
            }

        except Exception as e:
            logger.error("log_normalization_failed", error=str(e), raw_log=raw_log)
            # Return minimal OCSF on error
            return {
                "timestamp": datetime.utcnow(),  # Return datetime object
                "raw_log": str(raw_log),
                "message": raw_log.get("message", "Failed to normalize"),
                "ocsf": {
                    "class_uid": 3001,
                    "severity_id": 1,
                    "message": raw_log.get("message", "Failed to normalize"),
                },
                "source_ip": "0.0.0.0",
                "destination_ip": "0.0.0.0",
                "severity_id": 1,
                "category_uid": 3,
                "class_uid": 3001,
                "activity_id": 0,
                "status_id": 2,  # Failure
            }
