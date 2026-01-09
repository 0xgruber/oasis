FROM python:3.11-slim as base

LABEL org.opencontainers.image.title="O.A.S.I.S. External Gateway"
LABEL org.opencontainers.image.description="DMZ internet-facing log ingestion gateway"
LABEL org.opencontainers.image.authors="Aaron Gruber"
LABEL org.opencontainers.image.source="https://github.com/0xgruber/oasis"
LABEL org.opencontainers.image.licenses="MIT"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 gateway && \
    mkdir -p /app /certs && \
    chown -R gateway:gateway /app /certs

WORKDIR /app

# Install Poetry
ENV POETRY_VERSION=1.7.1 \
    POETRY_HOME=/opt/poetry \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN curl -sSL https://install.python-poetry.org | python3 - && \
    ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry

# Copy dependency files
COPY --chown=gateway:gateway pyproject.toml poetry.lock* ./

# Install dependencies
RUN poetry install --no-root --only main && \
    rm -rf ~/.cache/pypoetry

# Copy application code
COPY --chown=gateway:gateway src/ ./src/

# Switch to non-root user
USER gateway

# Expose ports
EXPOSE 443 514 6514

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=30s \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["poetry", "run", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
