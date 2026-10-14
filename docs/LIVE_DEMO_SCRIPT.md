# Multi-Cloud CI/CD & DevSecOps Pipeline — Live Demonstration Guide
**Student**: Dixith Babu A B (`24MIS0427`)  
**Course**: Agile Development Process And DevOps Lab (`ISWE406P`)  
**Faculty Evaluator**: Dr. Arunkumar  

---

## 📋 Pre-Demo Preparation (Set Up 2 Minutes Before)

Have these browser tabs and terminal ready on your screen:

1. **Tab 1 — GitHub Actions Pipeline**:
   `https://github.com/Dixith00/multicloud-devops-pipeline/actions`
2. **Tab 2 — AWS Management Console (Sydney ap-southeast-2)**:
   - Navigate to: **Amazon ECR** $\rightarrow$ **Repositories** $\rightarrow$ `multicloud-devops-pipeline-repo`
   - *Ensure Region is set to `Sydney (ap-southeast-2)`*
3. **Tab 3 — Microsoft Azure Portal (Central India)**:
   - Navigate to: **Resource Groups** $\rightarrow$ `rg-multicloud-pipeline` $\rightarrow$ **Container Registries** $\rightarrow$ `multiclouddevopspipeline` $\rightarrow$ **Repositories**
4. **Tab 4 — Local Terminal / VS Code**:
   - Working directory: `C:\Users\Dixith\Documents\antigravity\bold-darwin`
5. **Tab 5 — Presentation Deck & Project Report**:
   - Presentation: `docs/MultiCloud_DevOps_Presentation_Dixith_Babu_24MIS0427.pptx`
   - Formal Report: `docs/MultiCloud_DevOps_Project_Report_Dixith_Babu_24MIS0427.docx`

---

## 🎬 5-Stage Live Demonstration Flow

### Stage 1: Local Code Architecture & Security Validation (1.5 Minutes)
> **What to Say**:  
> *"Good morning/afternoon, Sir. I am Dixith Babu A B (24MIS0427). My project implements an enterprise-grade Multi-Cloud DevSecOps pipeline targeting both Amazon Web Services and Microsoft Azure. Before triggering cloud deployment, every artifact is strictly validated locally with automated unit testing and security hardening."*

1. **Show Project Structure in Terminal/VS Code**:
   - Point out:
     - `src/app.py`: Production Flask microservice with `/`, `/health`, and `/version` endpoints.
     - `src/Dockerfile`: Multi-stage, non-root container configuration (`UID 10001`).
     - `src/tests/test_app.py`: Comprehensive test suite.
     - `.github/workflows/multicloud-deploy.yml`: Multi-stage declarative CI/CD pipeline.

2. **Execute Automated Unit Tests**:
   Run in terminal:
   ```powershell
   python -m pytest src/tests/ -v
   ```
   **What to Highlight**:
   - Show that all **6/6 test cases pass** in ~2 seconds.
   - Explain tests cover root endpoints, health checks, version telemetry, and simulated cloud environment variable injection for AWS and Azure.

3. **Execute Static Code Analysis (Flake8)**:
   Run in terminal:
   ```powershell
   flake8 src --count --select=E9,F63,F7,F82 --show-source --statistics
   ```
   **What to Highlight**:
   - Zero syntax errors or critical logic flaws.

---

### Stage 2: Triggering the Pipeline with a Live Code Change (1 Minute)
> **What to Say**:  
> *"Now, I will make a live code change to demonstrate automated GitOps triggering. Any push to the main branch automatically passes through our DevSecOps quality gates before being concurrently pushed to both cloud providers."*

1. **Update `src/app.py`**:
   Change line 43 message:
   ```python
   "message": "Production Multi-Cloud CI/CD - Evaluated Live by Dr. Arunkumar",
   ```
2. **Commit and Push to GitHub**:
   ```powershell
   git add .
   git commit -m "feat: live demonstration update for Dr. Arunkumar"
   git push origin main
   ```
3. *Alternative (if already up to date)*:
   Go to GitHub Actions tab $\rightarrow$ Click **"Multi-Cloud Production CI/CD & DevSecOps Pipeline"** $\rightarrow$ Click **"Run workflow"** button $\rightarrow$ Branch: `main` $\rightarrow$ Click **"Run workflow"**.

---

### Stage 3: Live GitHub Actions Pipeline Walkthrough (2-3 Minutes)
> **What to Say**:  
> *"Here in GitHub Actions, the workflow has triggered. It is split into 3 distinct jobs to guarantee security and multi-cloud resilience."*

1. **Job 1: `ci-security` (CI & DevSecOps Quality Gate)**:
   - **Step 1**: Sets up Python 3.11 runtime and caches dependencies.
   - **Step 2**: Runs `flake8` for PEP8 compliance and syntax verification.
   - **Step 3**: Executes `pytest` test suite generating JUnit XML test reports.
   - **Step 4**: Builds the container image locally.
   - **Step 5**: Runs **Aqua Trivy Vulnerability Scanner** on the built image for `CRITICAL` and `HIGH` CVEs.
   - **Step 6**: Runs Trivy Filesystem scan to detect accidental secret leaks or IaC misconfigurations.

2. **Job 2: `deploy-aws` (Amazon Web Services)**:
   - Authenticates using GitHub Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
   - Targets region **Sydney (`ap-southeast-2`)**.
   - Authenticates Docker to Amazon ECR.
   - Builds and tags the image with both the **Git Commit SHA** (`${{ github.sha }}`) and `latest`.
   - Pushes both immutable tags to `multicloud-devops-pipeline-repo`.

3. **Job 3: `deploy-azure` (Microsoft Azure)**:
   - Authenticates to Azure via Service Principal credentials (`AZURE_CREDENTIALS`).
   - Targets region **Central India (`centralindia`)**.
   - Validates resource group `rg-multicloud-pipeline` and Azure Container Registry (ACR).
   - Authenticates Docker client and publishes the dual-tagged image to `multiclouddevopspipeline.azurecr.io`.

---

### Stage 4: Proving Multi-Cloud Persistence in Cloud Consoles (2 Minutes)
> **What to Say**:  
> *"Now I will verify that the built and scanned container images are stored securely across both AWS and Azure in real-time."*

1. **AWS Management Console Verification**:
   - Switch to **AWS Console** tab.
   - Point out region in top right: **Sydney (`ap-southeast-2`)**.
   - Open **Amazon ECR** $\rightarrow$ **Repositories** $\rightarrow$ `multicloud-devops-pipeline-repo`.
   - **Show the Professor**:
     - The latest image tag matching the exact Git commit SHA you just pushed.
     - The `latest` tag pointing to the same image digest.
     - The optimized image size (~55 MB due to multi-stage slim Python base).
     - Image scan status showing automated vulnerability assessment.

2. **Azure Portal Verification**:
   - Switch to **Azure Portal** tab.
   - Open **Resource Groups** $\rightarrow$ `rg-multicloud-pipeline` in **Central India**.
   - Click on Container Registry (`multiclouddevopspipeline`).
   - Under **Services**, click **Repositories** $\rightarrow$ `multicloud-devops-pipeline`.
   - **Show the Professor**:
     - The image tag matching the exact same Git commit SHA.
     - The `latest` tag and SHA256 manifest digest.
     - State that both cloud registries now hold parity for zero-downtime failover.

---

### Stage 5: Live API Endpoint Testing & Parity Probing (1 Minute)
> **What to Say**:  
> *"Finally, we verify that the microservice provides comprehensive operational health telemetry and active parity."*

1. **Run Application Locally (or probe deployed endpoint)**:
   In a terminal:
   ```powershell
   python src/app.py
   ```
2. **Open in Browser or PowerShell**:
   - **Root Endpoint (`/`)**:
     `http://127.0.0.1:8080/`
     Shows JSON status, provider detection, and live timestamp.
   - **Health Check Endpoint (`/health`)**:
     `http://127.0.0.1:8080/health`
     Returns `{"status": "healthy", "service": "multicloud-devops-pipeline"}` with HTTP 200.
   - **Version Endpoint (`/version`)**:
     `http://127.0.0.1:8080/version`
     Returns current version `1.0.0` and Git commit metadata.

---

## 💡 Anticipated Professor Questions & Winning Answers

### Q1: "Why did you use Sydney (`ap-southeast-2`) for AWS and Central India for Azure?"
> **Answer**:  
> *"In real-world enterprise engineering, AWS organizations frequently apply Service Control Policies (SCPs) restricting or throttling default regions like `us-east-1`. When testing my AWS account, `us-east-1` had organizational restrictions, so I adapted the pipeline to target Sydney (`ap-southeast-2`), which provides full ECR and compute capabilities. For Azure, I deployed to `centralindia` to achieve geographic and network diversity, reducing single-region blast radius and ensuring high availability across the Indo-Pacific corridor."*

### Q2: "How does your pipeline ensure DevSecOps rather than just basic CI/CD?"
> **Answer**:  
> *"We implement 'Shift-Left' security at three layers:  
> 1. Static code analysis and linting with Flake8 to catch anti-patterns before runtime.  
> 2. Aqua Trivy container scanning to inspect all OS packages and pip dependencies for CRITICAL and HIGH CVEs before registry publication.  
> 3. Filesystem and IaC security scanning to prevent any accidental credential leakage. Furthermore, our Dockerfile runs as a non-root user (`UID 10001`), preventing container breakout vulnerabilities."*

### Q3: "Why do you push two tags: `${{ github.sha }}` and `latest`?"
> **Answer**:  
> *"Pushing `latest` allows orchestration platforms and monitoring tools to automatically track the newest deployment. Pushing the immutable Git commit SHA tag (`${{ github.sha }}`) provides cryptographic traceability back to the exact line of code in GitHub, enabling instant zero-downtime rollbacks if an incident occurs."*

### Q4: "What happens if AWS goes down completely?"
> **Answer**:  
> *"Because our deployment job publishes identical container images and environment parity to Azure Container Registry in Central India simultaneously, global DNS or traffic management can route incoming user requests to the Azure cluster immediately with zero code changes or rebuilds needed."*
