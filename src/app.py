"""Multi-Cloud DevOps Pipeline - Core REST API Service.

Exposes endpoints for root service discovery, health monitoring, and version
metadata across AWS and Azure deployments.
"""

import os
import platform
import time
from datetime import datetime, timezone
from typing import Any, Dict

from flask import Flask, jsonify, request

START_TIME = time.time()


def create_app() -> Flask:
    """Application factory for Flask REST API.

    Returns:
        Flask: Configured Flask application instance.
    """
    app = Flask(__name__)

    @app.before_request
    def log_request_info() -> None:
        """Log incoming request path and method for observability."""
        app.logger.debug("Handling request %s %s", request.method, request.path)

    @app.route("/", methods=["GET"])
    def root() -> tuple[Dict[str, Any], int]:
        """Root endpoint returning service identity and cloud metadata.

        Returns:
            tuple[Dict[str, Any], int]: Response payload and HTTP status code.
        """
        cloud_provider = os.environ.get("CLOUD_PROVIDER", "local-development")
        region = os.environ.get("REGION", "local-node")
        payload = {
            "service": "multicloud-devops-pipeline",
            "status": "online",
            "message": "Production Multi-Cloud CI/CD - Evaluated Live",
            "cloud_provider": cloud_provider,
            "region": region,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "endpoints": {
                "root": "/",
                "health": "/health",
                "version": "/version",
            },
        }
        return jsonify(payload), 200

    @app.route("/health", methods=["GET"])
    def health() -> tuple[Dict[str, Any], int]:
        """Health check endpoint for container probes and load balancers.

        Returns:
            tuple[Dict[str, Any], int]: Health payload and HTTP status code.
        """
        cloud_provider = os.environ.get("CLOUD_PROVIDER", "local-development")
        region = os.environ.get("REGION", "local-node")
        uptime = round(time.time() - START_TIME, 2)
        payload = {
            "status": "healthy",
            "cloud_provider": cloud_provider,
            "region": region,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "uptime_seconds": uptime,
            "system": {
                "python_version": platform.python_version(),
                "platform": platform.platform(),
            },
        }
        return jsonify(payload), 200

    @app.route("/version", methods=["GET"])
    def version() -> tuple[Dict[str, Any], int]:
        """Version endpoint reporting build and commit metadata.

        Returns:
            tuple[Dict[str, Any], int]: Version payload and HTTP status code.
        """
        cloud_provider = os.environ.get("CLOUD_PROVIDER", "local-development")
        region = os.environ.get("REGION", "local-node")
        app_version = os.environ.get("APP_VERSION", "1.0.0")
        commit_sha = os.environ.get("COMMIT_SHA", "dev-local")
        build_timestamp = os.environ.get("BUILD_TIMESTAMP", "unspecified")

        payload = {
            "service": "multicloud-devops-pipeline",
            "version": app_version,
            "commit_sha": commit_sha,
            "build_timestamp": build_timestamp,
            "cloud_provider": cloud_provider,
            "region": region,
        }
        return jsonify(payload), 200

    @app.errorhandler(404)
    def not_found(error: Any) -> tuple[Dict[str, Any], int]:
        """Handle 404 errors with standardized JSON output."""
        return jsonify({
            "error": "Not Found",
            "message": "The requested resource was not found on this server.",
            "status_code": 404,
        }), 404

    @app.errorhandler(500)
    def internal_error(error: Any) -> tuple[Dict[str, Any], int]:
        """Handle 500 errors with standardized JSON output."""
        return jsonify({
            "error": "Internal Server Error",
            "message": "An unexpected error occurred processing the request.",
            "status_code": 500,
        }), 500

    return app


app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
