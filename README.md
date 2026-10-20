# Multi-Cloud DevOps Pipeline: Production AWS & Azure CI/CD Platform

[![CI/CD Pipeline](https://img.shields.io/badge/GitHub%20Actions-Multi--Cloud%20Pipeline-blue?logo=githubactions)](https://github.com)
[![Python Version](https://img.shields.io/badge/Python-3.11%20%7C%203.12%20%7C%203.13-brightgreen?logo=python)](https://python.org)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-purple?logo=terraform)](https://terraform.io)
[![AWS Free Tier](https://img.shields.io/badge/AWS-ap--south--1%20Free%20Tier-orange?logo=amazon-aws)](https://aws.amazon.com)
[![Azure Free Tier](https://img.shields.io/badge/Azure-F1%20Free%20Tier-0078D4?logo=microsoft-azure)](https://azure.microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

An enterprise-grade, multi-cloud CI/CD and DevSecOps reference implementation deploying a hardened containerized REST API simultaneously to **Amazon Web Services (AWS)** and **Microsoft Azure**.

---

## 1. Architectural Highlights

- **Simultaneous Dual-Cloud Continuous Deployment**: Concurrently builds, tags, and deploys container images to **AWS (Amazon ECR + AWS App Runner)** and **Microsoft Azure (Azure Container Registry + Azure Linux App Service F1)** on merges to `main`.
- **Shift-Left DevSecOps Pipeline**: Incorporates automated PEP 8 linting (`flake8`), regression testing (`pytest`), and static vulnerability scanning (`Trivy` container & filesystem scans) prior to cloud artifact promotion.
- **Hardened Multi-Stage Container**: Distroless-like multi-stage `Dockerfile` executing under a dedicated non-root user (`appuser`, UID `10001`) with read-only application files (`chmod 550`).
- **100% Free-Tier Allocation Model**:
  - **AWS**: Region `ap-south-1` (Mumbai) using private ECR repository with automatic 10-image lifecycle policy retention and App Runner free tier compute.
  - **Azure**: Region `Central India` (Pune) using Linux App Service on the permanent `F1` Free Tier SKU with Azure Container Registry (Basic SKU).

---

## 2. Repository Layout

```
multicloud-devops-pipeline/
├── .github/
│   └── workflows/
│       └── multicloud-deploy.yml   # Multi-cloud 3-job CI/CD/DevSecOps pipeline
├── docs/
│   ├── ARCHITECTURE.md             # System architecture, ASCII diagrams & DR model
│   └── AGILE_BOARD.md              # 3 Sprints, Gherkin user stories & Kanban schema
├── src/
│   ├── app.py                      # Flask REST API with cloud discovery telemetry
│   ├── Dockerfile                  # Multi-stage hardened non-root container image
│   ├── requirements.txt            # Pinned production and test dependencies
│   ├── tests/
│   │   ├── __init__.py             # Python test package indicator
│   │   └── test_app.py             # Pytest suite verifying status codes & payloads
│   └── __init__.py                 # Python package indicator
├── terraform/
│   ├── main.tf                     # AWS ECR/AppRunner & Azure RG/ACR/AppService IaC
│   ├── outputs.tf                  # Exported registry URIs and public service URLs
│   ├── variables.tf                # Free-tier region and parameter declarations
│   └── versions.tf                 # Pinned providers (~> 5.0 for AWS, ~> 3.0 for Azure)
├── .dockerignore                   # Docker build context exclusions
├── .gitignore                      # Git repository exclusions
├── Dockerfile                      # Root-level multi-stage container build target
├── pyproject.toml                  # Pytest & Flake8 tooling configuration
├── README.md                       # Complete deployment & quick-start manual
└── setup.sh                        # Automated local testing & validation suite
```

---

## 3. Microservice REST API Specification

The core microservice is a production WSGI application served via Gunicorn. It dynamically detects and reports the underlying cloud platform, region, and uptime.

### Available Endpoints

| Method | Endpoint | Description | Sample Output |
| :--- | :--- | :--- | :--- |
| `GET` | `/` | Root service discovery & cloud metadata | `{"cloud_provider": "AWS", "region": "ap-south-1", "status": "online"}` |
| `GET` | `/health` | Liveness & readiness probe for load balancers | `{"status": "healthy", "uptime_seconds": 124.5, "system": {...}}` |
| `GET` | `/version` | Build traceability & Git commit SHA | `{"version": "1.0.0", "commit_sha": "a7b3c9...", "cloud_provider": "Azure"}` |

### Example Payloads

#### `GET /health`
```json
{
  "cloud_provider": "AWS",
  "region": "ap-south-1",
  "status": "healthy",
  "system": {
    "platform": "Linux-5.15.0-x86_64",
    "python_version": "3.11.9"
  },
  "timestamp": "2026-10-13T05:15:30.123456+00:00",
  "uptime_seconds": 3600.42
}
```

---

## 4. Local Quick-Start & Development

### Prerequisites
- Python 3.11+
- Git
- Docker (optional for container testing)
- Terraform 1.5+ (optional for IaC provisioning)

### Local Environment Setup
```bash
# 1. Clone the repository
git clone https://github.com/example/multicloud-devops-pipeline.git
cd multicloud-devops-pipeline

# 2. Create and activate a Python virtual environment
python -m venv venv
# On Linux/macOS:
source venv/bin/activate
# On Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# 3. Install pinned dependencies
pip install -r src/requirements.txt

# 4. Run automated unit tests
pytest src/tests -v

# 5. Run static analysis and linting
flake8 src --count --max-complexity=10 --max-line-length=120 --statistics
```

### Automated One-Click Verification Script
Run the automated test, container build, and Terraform syntax check suite:
```bash
chmod +x setup.sh
./setup.sh
```

---

## 5. GitHub Repository Secrets Configuration

To enable automated deployments across both clouds, configure the following secrets in **GitHub Repository Settings -> Secrets and variables -> Actions**:

| Secret Name | Cloud Provider | Description | How to Generate |
| :--- | :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS | IAM User Access Key ID with ECR & App Runner privileges | AWS Console -> IAM -> Users -> Security credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS | IAM User Secret Access Key | Paired with `AWS_ACCESS_KEY_ID` upon creation |
| `AZURE_CREDENTIALS` | Azure | Service Principal JSON credentials | Generated via `az ad sp create-for-rbac` (see below) |
| `AZURE_ACR_NAME` | Azure | Alphanumeric Azure Container Registry name | Output from `terraform output azure_acr_name` |

### Generating Azure Service Principal Credentials
Run the following Azure CLI command in your terminal to generate the JSON payload for `AZURE_CREDENTIALS`:

```bash
az ad sp create-for-rbac \
  --name "sp-multicloud-devops-pipeline" \
  --role "Contributor" \
  --scopes "/subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID>" \
  --sdk-auth
```

Paste the entire resulting JSON object into the `AZURE_CREDENTIALS` secret:
```json
{
  "clientId": "<client-id>",
  "clientSecret": "<client-secret>",
  "subscriptionId": "<subscription-id>",
  "tenantId": "<tenant-id>",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

---

## 6. Infrastructure as Code (IaC) Deployment Guide

### Initialize and Plan Infrastructure
```bash
cd terraform

# Initialize provider plugins (AWS ~> 5.0, AzureRM ~> 3.0)
terraform init

# Validate configuration syntax and resource graph
terraform validate

# Review proposed cloud resource changes
terraform plan -out=tfplan
```

### Apply Infrastructure
```bash
# Provision resources across AWS (ap-south-1) and Azure (Central India)
terraform apply tfplan
```

### Inspect Output Endpoints
```bash
terraform output
```
Sample outputs:
```
aws_apprunner_service_url = "https://a1b2c3d4e5.ap-south-1.awsapprunner.com"
aws_ecr_repository_url    = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/multicloud-devops-pipeline-repo"
azure_acr_login_server    = "acrmulticloud123abc.azurecr.io"
azure_acr_name            = "acrmulticloud123abc"
azure_app_service_url     = "https://app-multicloud-devops-pipeline-123abc.azurewebsites.net"
```

---

## 7. Cloud Teardown Protocol

To ensure 100% adherence to economics and prevent any unexpected charges after testing or demonstration:

```bash
cd terraform

# Destroy all cloud resources simultaneously across AWS and Azure
terraform destroy -auto-approve
```

### Teardown Verification Checklist
1. **AWS Verification**:
   ```bash
   # Confirm App Runner service deletion
   aws apprunner list-services --region ap-south-1
   # Confirm ECR repository deletion
   aws ecr describe-repositories --region ap-south-1
   ```
2. **Azure Verification**:
   ```bash
   # Confirm Resource Group removal (deletes ACR and App Service)
   az group exists --name "rg-multicloud-devops-pipeline-prod"
   ```

---

## 8. Academic Review & Technical Defense Notes

When presenting this project during technical evaluation or defense:

1. **Active-Active Resilience**: Explain that pushing standardized OCI container images simultaneously to AWS ECR and Azure ACR guarantees cloud vendor portability. If one cloud provider experiences a regional degradation, the independent cloud instance remains fully functional.
2. **Automated DevSecOps Pipeline**: Emphasize that the GitHub Actions workflow acts as a strict gatekeeper: code cannot be pushed to cloud registries unless unit tests pass, cyclomatic complexity is below 10, and Trivy verifies the container image has no unfixed critical CVEs.
3. **Hardened Container Security**: Point out that the container avoids root execution (`USER 10001:10001`), builds in isolated virtual environment layers, and exposes health probes via standard library modules without requiring external network binaries (`curl` or `wget`).
4. **Free Tier Financial Governance**: Highlight that Azure Linux App Service `F1` and AWS App Runner with ECR lifecycle policies keep monthly infrastructure costs at exactly **$0.00**.
