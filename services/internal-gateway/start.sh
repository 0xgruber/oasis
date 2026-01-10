#!/bin/bash
# O.A.S.I.S. Gateway Service Startup Script
# Configures TLS if certificates are available

set -e

# Check if certificates exist
if [[ -f "$MTLS_CERT_PATH" ]] && [[ -f "$MTLS_KEY_PATH" ]]; then
    echo "Starting gateway with HTTPS..."
    echo "Gateway Type: $GATEWAY_TYPE"
    echo "Certificate: $MTLS_CERT_PATH"
    echo "Key: $MTLS_KEY_PATH"
    
    exec poetry run uvicorn src.main:app \
        --host 0.0.0.0 \
        --port 8000 \
        --ssl-certfile "$MTLS_CERT_PATH" \
        --ssl-keyfile "$MTLS_KEY_PATH"
else
    echo "WARNING: TLS certificates not found, starting with HTTP only"
    echo "Certificate check: $MTLS_CERT_PATH ($([ -f "$MTLS_CERT_PATH" ] && echo 'found' || echo 'missing'))"
    echo "Key check: $MTLS_KEY_PATH ($([ -f "$MTLS_KEY_PATH" ] && echo 'found' || echo 'missing'))"
    
    exec poetry run uvicorn src.main:app \
        --host 0.0.0.0 \
        --port 8000
fi
