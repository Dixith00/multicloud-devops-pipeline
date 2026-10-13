# Multi-Cloud DevOps Pipeline: System Architecture & Design Specification

## 1. Executive Summary & Architecture Philosophy

The **multicloud-devops-pipeline** is an enterprise-grade, zero-cost, multi-cloud CI/CD and DevSecOps platform engineered to deliver automated, simultaneous container deployments across **Amazon Web Services (AWS)** and **Microsoft Azure**.

### Core Tenets
1. **Cloud Agnosticism & Resilience**: Decouples application logic from proprietary cloud services using standardized OCI container images, POSIX-compliant runtime environments, and open Infrastructure as Code (Terraform).
2. **Shift-Left DevSecOps**: Integrates security gates directly into the developer workflow. Vulnerability scanning (Trivy), static analysis (flake8), and automated regression testing (pytest) execute prior to any cloud artifact promotion.
3. **Strict Zero-Cost Engineering**: Tailored specifically to fit permanent and 12-month cloud Free Tier quotas without compromising production readiness:
   - **AWS**: Amazon ECR private repository with auto-pruning lifecycle policies and App Runner managed runtime in `ap-south-1` (Mumbai).
   - **Azure**: Azure Container Registry (Basic SKU) and Linux App Service Plan on the 100% free `F1` SKU in `Central India` (Pune).

---

## 2. ASCII System Architecture Diagram

```
+--------------------------------------------------------------------------------------------------+
|                                    DEVELOPER WORKSPACE / GIT VCS                                 |
+--------------------------------------------------------------------------------------------------+
                                                 |
                                         git push origin main
                                                 v
+--------------------------------------------------------------------------------------------------+
|                                  GITHUB ACTIONS RUNNER (UBUNTU-LATEST)                           |
|                                                                                                  |
|   +------------------------------------------------------------------------------------------+   |
|   | Job 1: ci-security (Quality & DevSecOps Gate)                                            |   |
|   |                                                                                          |   |
|   |  [Source Checkout] ---> [Flake8 Linter] ---> [Pytest Suite] ---> [Trivy Vulnerability]   |   |
|   |      (actions/v4)       (PEP8 / AST)         (Unit Tests)         (OS & Library CVEs)    |   |
|   +------------------------------------------------------------------------------------------+   |
|                                                |                                                 |
|                      +-------------------------+-------------------------+                       |
|                      | (Passed Quality Gate - Parallel Dispatch)          |                       |
|                      v                                                   v                       |
|   +--------------------------------------+   +-----------------------------------------------+   |
|   | Job 2: deploy-aws                    |   | Job 3: deploy-azure                           |   |
|   |                                      |   |                                               |   |
|   | 1. Assume IAM Role / Keys            |   | 1. Azure CLI Service Principal Login          |   |
|   | 2. ECR Docker Login                  |   | 2. ACR Docker Login                           |   |
|   | 3. Multi-stage Docker Build          |   | 3. Multi-stage Docker Build                   |   |
|   | 4. Tag (Commit SHA + Latest)         |   | 4. Tag (Commit SHA + Latest)                  |   |
|   | 5. Push to ECR                       |   | 5. Push to ACR                                |   |
|   | 6. Trigger App Runner Service Update |   | 6. Deploy Container to Linux Web App (F1)     |   |
|   +--------------------------------------+   +-----------------------------------------------+   |
+--------------------------------------------------------------------------------------------------+
                       |                                                   |
                       | (HTTPS / OCI Push)                                | (HTTPS / OCI Push)
                       v                                                   v
+--------------------------------------------------+  +--------------------------------------------+
|            AMAZON WEB SERVICES (AWS)             |  |           MICROSOFT AZURE                  |
|            Region: ap-south-1 (Mumbai)           |  |           Region: Central India (Pune)     |
|                                                  |  |                                            |
|   +------------------------------------------+   |  |   +------------------------------------+   |
|   | Amazon Elastic Container Registry (ECR)  |   |  |   | Azure Container Registry (ACR)     |   |
|   | - Immutable OCI Artifacts                |   |  |   | - Basic SKU (Admin Enabled)        |   |
|   | - Scan-on-Push Enabled                   |   |  |   | - Encrypted Storage                |   |
|   | - 10-Image Retention Lifecycle Policy    |   |  |   +------------------------------------+   |
|   +------------------------------------------+   |                         |                     |
|                        |                         |                         v                     |
|                        v                         |  +------------------------------------+       |
|   +------------------------------------------+   |  | Azure App Service Linux Plan (F1)  |       |
|   | AWS App Runner / ECS Fargate Skeleton    |   |  | - Web App for Containers           |       |
|   | - Managed Auto-Scaling Container Host    |   |  | - Port 8080 exposed                |       |
|   | - Non-root Appuser (UID 10001)           |   |  | - Non-root Appuser (UID 10001)     |       |
|   | - Health Check Probe: /health            |   |  | - Health Check Probe: /health      |       |
|   +------------------------------------------+   |  +------------------------------------+       |
+--------------------------------------------------+  +--------------------------------------------+
                       |                                                   |
                       +-------------------------+-------------------------+
                                                 |
                                                 v
+--------------------------------------------------------------------------------------------------+
|                            GLOBAL TRAFFIC / DUAL-CLOUD INGRESS                                   |
|                     (Cloudflare / Route 53 / Azure Traffic Manager)                              |
|                                                                                                  |
|   [Active-Active Round Robin / Geo-DNS] ---> Health Check Monitoring (/health)                   |
|   AWS Node: https://<aws-apprunner-url>/health   <--->   Azure Node: https://<azure-app>/health  |
+--------------------------------------------------------------------------------------------------+
```

---

## 3. End-to-End GitOps Workflow

### Phase A: Developer Stage & Local Verification
1. Developers implement features or bug fixes in local feature branches.
2. The local verification script (`./setup.sh`) executes linting, unit test suites, and Docker container verification locally.
3. Code is pushed to GitHub, initiating the automated pipeline.

### Phase B: Automated CI & Security Quality Gate (`ci-security`)
Every pull request or commit to `main` runs in a clean `ubuntu-latest` virtual environment:
- **Code Checkout**: Clones the commit tree.
- **Dependency Resolution**: Installs pinned dependencies from `src/requirements.txt`.
- **Static Code Analysis (flake8)**: Scans for syntax anomalies, undeclared variables, cyclomatic complexity violations, and PEP 8 conformity.
- **Unit & Integration Testing (pytest)**: Executes test suites validating JSON contracts, HTTP status codes, and cloud-provider environment variable injection.
- **Container Build & Trivy Scan**: Builds the local OCI container image using multi-stage caching and executes `aquasecurity/trivy-action` across both container layers and the host repository filesystem.

### Phase C: Parallel Multi-Cloud CD Dispatch (`deploy-aws` & `deploy-azure`)
Upon successful completion of `ci-security` on the `main` branch, two independent CD jobs launch concurrently:

#### AWS CD Track:
1. Authenticates against AWS IAM using short-lived credentials derived from repository secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
2. Obtains an authenticated Docker login token for Amazon ECR via `aws-actions/amazon-ecr-login`.
3. Compiles the production container with dual tags: `${GITHUB_SHA}` (immutable audit trail) and `latest` (runtime pointer).
4. Pushes layers to Amazon ECR. ECR automatically executes a server-side vulnerability scan upon push.
5. Invokes the AWS App Runner API via AWS CLI to trigger a rolling zero-downtime deployment.

#### Azure CD Track:
1. Authenticates against Microsoft Entra ID (Azure AD) via Service Principal JSON secret (`AZURE_CREDENTIALS`).
2. Extracts ACR login server and credentials via `az acr credential show`.
3. Builds and tags the Docker image: `${ACR_LOGIN_SERVER}/multicloud-devops-pipeline:${GITHUB_SHA}` and `latest`.
4. Pushes image layers to Azure Container Registry.
5. Updates the Azure Linux Web App container configuration and triggers a rolling container restart via Azure CLI.

---

## 4. DevSecOps & Shift-Left Security Framework

| Security Layer | Tool / Mechanism | Implementation Details |
| :--- | :--- | :--- |
| **Code Linting & SAST** | `flake8` | Analyzes Abstract Syntax Trees (AST) to prevent syntax errors, unused imports, and unhandled exceptions prior to compilation. |
| **Automated Testing** | `pytest` | Validates API contracts, status codes (200, 404), JSON payload structures, and cloud variable isolation. |
| **Vulnerability Scanning** | `Trivy` (Aqua Security) | Analyzes base OS libraries (Debian Bookworm) and Python wheels against the National Vulnerability Database (NVD). |
| **Container Hardening** | Multi-Stage Dockerfile | Builds wheels in a disposable builder stage; runtime image contains only application files and zero build tools. |
| **Least-Privilege Execution**| Non-Root User (UID 10001) | Application runs strictly under `appuser:appgroup` (UID/GID 10001) with read-only application file permissions (`chmod 550`). |
| **Secret Management** | GitHub Encrypted Secrets | No plaintext credentials exist in git history; secrets are injected as masked runtime variables in GitHub runners. |
| **Artifact Retention** | ECR Lifecycle Policies | Restricts retained images to 10 releases and purges untagged artifacts after 7 days, preventing resource exhaustion and cost spikes. |

---

## 5. Multi-Cloud Resilience & Disaster Recovery

### Active-Active Deployment Model
Because identical container artifacts are simultaneously published to both AWS and Azure:
- **Zero Cloud Lock-In**: The application relies strictly on standard environment variables (`CLOUD_PROVIDER`, `REGION`, `PORT`). Switching or adding clouds (e.g., GCP, OCI) requires no application rewrites.
- **Failover Routing**: By fronting the two endpoints with an active-active DNS health check (e.g., Cloudflare Load Balancing, Route 53 Latency Routing, or Azure Traffic Manager), incoming traffic automatically reroutes to the surviving cloud if an entire cloud provider region suffers an outage.
- **RTO & RPO**:
  - **Recovery Time Objective (RTO)**: < 30 seconds (automated DNS health probe failover).
  - **Recovery Point Objective (RPO)**: 0 seconds (stateless microservice tier with identical deployment versions).

---

## 6. Zero-Cost Free-Tier Financial Governance

| Resource Component | Cloud Provider | Free Tier Allocation | Project Usage | Cost Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Amazon ECR** | AWS | 500 MB / month private storage | ~65 MB per image (pruned to 10 images) | **$0.00 / mo** |
| **AWS App Runner** | AWS | 12-month Free Tier credits (compute) | Single lightweight microservice | **$0.00 / mo** |
| **Azure App Service Plan**| Azure | F1 Free Tier (60 CPU minutes/day) | Permanent Free Linux container host | **$0.00 / mo** |
| **Azure ACR** | Azure | Basic SKU | Standard container registry | Included in credits / minimal |
| **GitHub Actions** | GitHub | 2,000 free minutes/month for public/private | ~1.5 minutes per pipeline run | **$0.00 / mo** |

---

## 7. Operational Health Probing & Verification

The microservice exposes three dedicated endpoints tailored for automated probes:

1. **Root (`GET /`)**:
   Provides service discovery, confirming the running microservice identity, deployment target, and API directory.
2. **Health Probe (`GET /health`)**:
   Returns HTTP 200 with runtime uptime in seconds and system metrics. Used by AWS App Runner and Azure App Service health monitors.
3. **Version Metadata (`GET /version`)**:
   Returns the active Git commit SHA and application build version, verifying that the deployed container matches the latest GitHub commit.
