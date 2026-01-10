#!/bin/bash
# O.A.S.I.S. Ingestion Service Startup Script
# Configures TLS (mTLS is handled at application layer, not uvicorn)

set -e

# Check if certificates exist
if [[ -f "$MTLS_CERT_PATH" ]] && [[ -f "$MTLS_KEY_PATH" ]]; then
    echo "Starting ingestion service with HTTPS..."
    echo "Certificate: $MTLS_CERT_PATH"
    echo "Key: $MTLS_KEY_PATH"
    echo "Note: Client certificate verification handled at application layer"
    
    exec poetry run uvicorn src.main:app \
        --host 0.0.0.0 \
        --port 8080 \
        --ssl-certfile "$MTLS_CERT_PATH" \
        --ssl-keyfile "$MTLS_KEY_PATH"
else
    echo "WARNING: TLS certificates not found, starting with HTTP only"
    echo "Certificate check: $MTLS_CERT_PATH ($([ -f "$MTLS_CERT_PATH" ] && echo 'found' || echo 'missing'))"
    echo "Key check: $MTLS_KEY_PATH ($([ -f "$MTLS_KEY_PATH" ] && echo 'found' || echo 'missing'))"
    
    exec poetry run uvicorn src.main:app \
        --host 0.0.0.0 \
        --port 8080
fi
