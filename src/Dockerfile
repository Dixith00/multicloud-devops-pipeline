# ==============================================================================
# Stage 1: Build & Dependency Resolution Stage
# ==============================================================================
FROM python:3.11-slim-bookworm AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create isolated Python virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install production dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ==============================================================================
# Stage 2: Hardened Runtime Container
# ==============================================================================
FROM python:3.11-slim-bookworm AS runner

LABEL maintainer="Multi-Cloud DevOps Core Team" \
      org.opencontainers.image.title="multicloud-devops-pipeline" \
      org.opencontainers.image.description="Production-grade, zero-cost multi-cloud REST API for AWS and Azure" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    CLOUD_PROVIDER="container-local" \
    REGION="local-region"

# Security: Create non-root system group and user
RUN groupadd --system --gid 10001 appgroup && \
    useradd --system --uid 10001 --gid appgroup --no-create-home --shell /sbin/nologin appuser

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy application source code
COPY app.py /app/app.py

# Set proper ownership and permissions
RUN chown -R appuser:appgroup /app /opt/venv && \
    chmod -R 550 /app && \
    chmod -R 550 /opt/venv

# Run as non-privileged user
USER 10001:10001

EXPOSE 8080

# Health check using python urllib (no curl/wget dependency required)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/health', timeout=4).getcode() == 200 else 1)"

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--worker-class", "gthread", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
