"""Pytest test suite for Multi-Cloud DevOps Pipeline REST API."""

import os
import sys

# Ensure src directory is present in sys.path across all platforms and test runners
SRC_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

import pytest  # noqa: E402
from app import create_app  # noqa: E402


@pytest.fixture
def client():
    """Create test client fixture for Flask application."""
    application = create_app()
    application.config["TESTING"] = True
    with application.test_client() as test_client:
        yield test_client


def test_root_endpoint_default_env(client, monkeypatch):
    """Verify root endpoint status code and payload structure with defaults."""
    monkeypatch.delenv("CLOUD_PROVIDER", raising=False)
    monkeypatch.delenv("REGION", raising=False)
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()

    assert data["service"] == "multicloud-devops-pipeline"
    assert data["status"] == "online"
    assert "Production Multi-Cloud CI/CD" in data["message"]
    assert data["cloud_provider"] == "local-development"
    assert data["region"] == "local-node"
    assert "timestamp" in data
    assert "endpoints" in data
    assert data["endpoints"]["health"] == "/health"
    assert data["endpoints"]["version"] == "/version"


def test_health_endpoint(client):
    """Verify health probe endpoint returns 200 and healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()

    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert isinstance(data["uptime_seconds"], (int, float))
    assert "system" in data
    assert "python_version" in data["system"]
    assert "platform" in data["system"]


def test_version_endpoint(client, monkeypatch):
    """Verify version endpoint reports version and commit information."""
    monkeypatch.delenv("APP_VERSION", raising=False)
    monkeypatch.delenv("COMMIT_SHA", raising=False)
    monkeypatch.delenv("BUILD_TIMESTAMP", raising=False)
    response = client.get("/version")
    assert response.status_code == 200
    data = response.get_json()

    assert data["service"] == "multicloud-devops-pipeline"
    assert data["version"] == "1.0.0"
    assert data["commit_sha"] == "dev-local"
    assert data["build_timestamp"] == "unspecified"


def test_aws_environment_injection(monkeypatch):
    """Verify API accurately reads and propagates AWS runtime variables."""
    monkeypatch.setenv("CLOUD_PROVIDER", "AWS")
    monkeypatch.setenv("REGION", "ap-south-1")
    monkeypatch.setenv("APP_VERSION", "2.1.0")
    monkeypatch.setenv("COMMIT_SHA", "aws987654321")

    app_instance = create_app()
    app_instance.config["TESTING"] = True
    with app_instance.test_client() as test_client:
        root_res = test_client.get("/")
        assert root_res.status_code == 200
        root_data = root_res.get_json()
        assert root_data["cloud_provider"] == "AWS"
        assert root_data["region"] == "ap-south-1"

        health_res = test_client.get("/health")
        assert health_res.status_code == 200
        health_data = health_res.get_json()
        assert health_data["cloud_provider"] == "AWS"
        assert health_data["region"] == "ap-south-1"

        version_res = test_client.get("/version")
        assert version_res.status_code == 200
        version_data = version_res.get_json()
        assert version_data["cloud_provider"] == "AWS"
        assert version_data["region"] == "ap-south-1"
        assert version_data["version"] == "2.1.0"
        assert version_data["commit_sha"] == "aws987654321"


def test_azure_environment_injection(monkeypatch):
    """Verify API accurately reads and propagates Azure runtime variables."""
    monkeypatch.setenv("CLOUD_PROVIDER", "Azure")
    monkeypatch.setenv("REGION", "Central India")
    monkeypatch.setenv("APP_VERSION", "3.0.0-rc1")
    monkeypatch.setenv("COMMIT_SHA", "az123456789")

    app_instance = create_app()
    app_instance.config["TESTING"] = True
    with app_instance.test_client() as test_client:
        root_res = test_client.get("/")
        assert root_res.status_code == 200
        root_data = root_res.get_json()
        assert root_data["cloud_provider"] == "Azure"
        assert root_data["region"] == "Central India"

        version_res = test_client.get("/version")
        assert version_res.status_code == 200
        version_data = version_res.get_json()
        assert version_data["cloud_provider"] == "Azure"
        assert version_data["region"] == "Central India"
        assert version_data["version"] == "3.0.0-rc1"


def test_not_found_handler(client):
    """Verify non-existent route returns formatted 404 JSON response."""
    response = client.get("/invalid-route-path")
    assert response.status_code == 404
    data = response.get_json()

    assert data["error"] == "Not Found"
    assert data["status_code"] == 404
