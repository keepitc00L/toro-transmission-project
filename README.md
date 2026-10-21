# ⚙️ Toro Transmission — CI/CD Pipeline & Kubernetes Deployment

**Official Web Application & DevOps Deployment for Toro Transmission — Premium manufacturer of industrial gear motors and power transmission solutions.**

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

---

## 📋 Table of Contents
1. [Project Overview](#-project-overview)
2. [CI/CD Pipeline Architecture](#-cicd-pipeline-architecture)
3. [Repository Structure](#-repository-structure)
4. [Docker Hub & Image Configuration](#-docker-hub--image-configuration)
5. [Kubernetes Manifests (Minikube)](#-kubernetes-manifests-minikube)
6. [Jenkins Setup & Credentials Configuration](#-jenkins-setup--credentials-configuration)
7. [Important: AWS Jenkins vs Local Minikube Connectivity](#-important-aws-jenkins-vs-local-minikube-connectivity)
8. [Step-by-Step Execution Guide](#-step-by-step-execution-guide)
9. [Demonstrating a Second Pipeline Run (Visible UI Change)](#-demonstrating-a-second-pipeline-run-visible-ui-change)
10. [CCA 2 Submission Screenshot Checklist](#-cca-2-submission-screenshot-checklist)
11. [CCA 2 Project Report](#-cca-2-project-report)

---

## 🌐 Project Overview

Toro Transmission is a responsive, modern web application for an industrial gear motor manufacturer. This project is configured with a production-grade CI/CD automation pipeline that builds an optimized Nginx container, performs automated smoke testing, pushes versioned images to Docker Hub, and automatically triggers a zero-downtime rolling update on a 2-replica Kubernetes cluster with NodePort access.

- **GitHub Repository**: [https://github.com/keepitc00L/toro-transmission-project](https://github.com/keepitc00L/toro-transmission-project)
- **Docker Hub Repository**: `maxspeed2020/toro-transmission`
- **Application Port**: Container Port `80` | Local Test Port `8888` | NodePort `30080`

---

## 🏗️ CI/CD Pipeline Architecture

```
  ┌─────────────────────────────────────────────────────────┐
  │                   Developer Workspace                   │
  │     git commit & push to GitHub (Release v2.0)          │
  └────────────────────────────┬────────────────────────────┘
                               │
                               ▼
  ┌─────────────────────────────────────────────────────────┐
  │                   Jenkins Pipeline                      │
  │                                                         │
  │  Stage 1: Checkout ──────────► Git clone source         │
  │  Stage 2: Lint & Validate ───► Validate HTML/CSS/K8s/Dkr│
  │  Stage 3: Docker Build ──────► Build & Tag image        │
  │  Stage 4: Test Container ────► Smoke test HTTP 200      │
  │  Stage 5: Docker Hub Push ───► Push to maxspeed2020     │
  │  Stage 6: K8s Deployment ────► Apply & Rolling Restart  │
  │  Stage 7: Verify Deploy ─────► Audit Pods & NodePort    │
  └────────────────────────────┬────────────────────────────┘
                               │
                               ▼
  ┌─────────────────────────────────────────────────────────┐
  │              Kubernetes Cluster (Minikube)              │
  │                                                         │
  │  ┌───────────────────────┐   ┌───────────────────────┐  │
  │  │ Pod 1: Nginx (Alpine) │   │ Pod 2: Nginx (Alpine) │  │
  │  │ maxspeed2020/toro:... │   │ maxspeed2020/toro:... │  │
  │  └───────────┬───────────┘   └───────────┬───────────┘  │
  │              └─────────────┬─────────────┘              │
  │                            ▼                            │
  │              NodePort Service (Port 30080)              │
  │                            │                            │
  │              http://<minikube-ip>:30080                 │
  └─────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
toro-transmission-project/
├── .dockerignore           # Excludes Git, docs, and manifests from Docker build
├── Dockerfile              # Production Nginx 1.27 Alpine multi-asset image
├── Jenkinsfile             # 7-Stage Declarative CI/CD Pipeline
├── nginx.conf              # Gzip, caching, and security header configuration
├── index.html              # Main website UI with live v2.0 build tag
├── style.css               # Premium styles, animations, responsive design
├── script.js               # Interactive functionality & particle animations
├── logo.png                # Corporate brand asset
├── gear_motor_1.png        # Product asset: Helical gear motor
├── gear_motor_2.png        # Product asset: Worm gear reducer
├── gear_motor_3.png        # Product asset: Planetary gearbox
├── gear_motor_4.png        # Product asset: Bevel helical drive
├── k8s/
│   ├── deployment.yaml     # 2 Replicas, rolling update, health probes
│   └── service.yaml        # NodePort Service exposing port 30080
└── README.md               # Assignment documentation, guide & CCA 2 report
```

---

## 🐳 Docker Hub & Image Configuration

- **Username**: `maxspeed2020`
- **Repository**: `maxspeed2020/toro-transmission`
- **Tags Generated on Every Build**:
  - `maxspeed2020/toro-transmission:${BUILD_NUMBER}` (Immutable audit tag)
  - `maxspeed2020/toro-transmission:latest` (Tracking tag)

### Testing Docker Locally
To build and test the container manually without Jenkins:
```bash
# 1. Build image
docker build -t maxspeed2020/toro-transmission:latest .

# 2. Run container locally on port 8888
docker run -d --name toro-local -p 8888:80 maxspeed2020/toro-transmission:latest

# 3. Test in browser or via curl
curl -I http://localhost:8888/

# 4. Clean up
docker rm -f toro-local
```

---

## ☸️ Kubernetes Manifests (Minikube)

### `k8s/deployment.yaml`
- **Replicas**: `2`
- **Image**: `maxspeed2020/toro-transmission:latest`
- **ImagePullPolicy**: `IfNotPresent` (pulls from Docker Hub when a new tag is deployed)
- **Strategy**: `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`
- **Probes**: Configured with `livenessProbe` and `readinessProbe` checking HTTP GET `/` on port 80.

### `k8s/service.yaml`
- **Type**: `NodePort`
- **Port**: `80` (Service Port)
- **TargetPort**: `80` (Pod Container Port)
- **NodePort**: `30080` (Cluster Node Port)

---

## ⚙️ Jenkins Setup & Credentials Configuration

### 1. Required Jenkins Plugins
Ensure the following plugins are installed in Jenkins (*Manage Jenkins > Plugins*):
- **Pipeline**
- **Git**
- **Credentials Binding Plugin**
- **Docker Pipeline**

### 2. Configure Docker Hub Credentials
1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials** → **Add Credentials**.
2. **Kind**: `Username with password`
3. **Username**: `maxspeed2020`
4. **Password**: *Your Docker Hub Personal Access Token (PAT) or Password*
5. **ID**: `docker-hub-credentials` *(Must match the ID in Jenkinsfile)*
6. **Description**: `Docker Hub Credentials for maxspeed2020`
7. Click **Create**.

---

## ⚠️ Important: AWS Jenkins vs Local Minikube Connectivity

> [!WARNING]
> **CRITICAL ARCHITECTURAL BOUNDARY:**
> If Jenkins is hosted on an **AWS EC2 instance**, and your **Minikube** cluster is running on your **local laptop (e.g., Windows 10/11 or macOS)**, AWS Jenkins **CANNOT directly reach** your local Minikube IP (`192.168.x.x` or `127.0.0.1`). Private IP addresses are not routable over the public Internet.

### How to Resolve Cluster Access for CCA 2:

#### Option A (Recommended for CCA 2 & Easiest): Run Minikube on the Jenkins Host
If Jenkins runs on an AWS EC2 instance (Ubuntu), install Docker, Kubectl, and Minikube directly on the same EC2 instance:
```bash
# On the EC2 Ubuntu instance:
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
minikube start --driver=docker --force
kubectl get nodes
```
This allows the Jenkins agent to communicate directly with Kubernetes via the local socket with zero networking bottlenecks.

#### Option B: Self-Hosted Jenkins Inbound Agent on Your Laptop
If Minikube must stay on your laptop:
1. In Jenkins (*Manage Jenkins > Nodes*), create a new Permanent Agent named `laptop-agent`.
2. Launch the agent on your laptop using the provided Java JNLP command.
3. In `Jenkinsfile`, set `agent { label 'laptop-agent' }`.
4. The build executes locally on your laptop, enabling direct access to `minikube` and `kubectl`.

#### Option C: Upload Kubeconfig to Jenkins Credentials Store
If deploying to an accessible remote cluster (or tunnelled Minikube):
1. In Jenkins, go to **Credentials** → **Add Credentials**.
2. **Kind**: `Secret file`
3. **File**: Upload your cluster `config` file.
4. **ID**: `k8s-kubeconfig`
5. The pipeline automatically binds `KUBECONFIG` to authenticate against the cluster.

---

## 🚀 Step-by-Step Execution Guide

### Step 1: Start Minikube & Prepare Cluster
```bash
minikube start
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -
```

### Step 2: Create the Pipeline Job in Jenkins
1. Open Jenkins Dashboard → **New Item**.
2. Enter item name: `toro-transmission-pipeline`.
3. Select **Pipeline** → Click **OK**.
4. In the **Pipeline** configuration section:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: `https://github.com/keepitc00L/toro-transmission-project.git`
   - **Branch Specifier**: `*/main` (or `*/master`)
   - **Script Path**: `Jenkinsfile`
5. Click **Save**.

### Step 3: Trigger Pipeline Execution
Click **Build Now** to run the pipeline. Watch the build logs across all 7 stages:
1. `Checkout`
2. `Lint & Validate`
3. `Docker Build`
4. `Test Container`
5. `Docker Hub Push`
6. `Kubernetes Deployment`
7. `Verify Deployment`

### Step 4: Verify Live Application in Minikube
```bash
# Check status of pods and deployment
kubectl get deployments
kubectl get pods -l app=toro-transmission -o wide
kubectl get svc toro-transmission-service

# Open service in browser
minikube service toro-transmission-service
# Or get URL directly:
minikube service toro-transmission-service --url
```

---

## 🔄 Demonstrating a Second Pipeline Run (Visible UI Change)

To satisfy the grading requirement demonstrating automated deployment between builds, the following visible change has been implemented in the codebase:

1. **Hero Badge Update**:
   - *Run 1*: `Industry Leaders Since 1995`
   - *Run 2*: `Industry Leaders Since 1995 • v2.0 (CI/CD Pipeline Run #2)`
2. **Footer Update**:
   - *Run 1*: Standard copyright
   - *Run 2*: `© 2026 Toro Transmission. All rights reserved. | Release v2.0 • Automated Deployment | Engineered with ❤️ in India`

When the second build finishes rolling out, refresh `http://<minikube-ip>:30080` to see the new v2.0 badge displayed without any server restart or downtime.

---

## 📸 CCA 2 Submission Screenshot Checklist

Capture the following screenshots to provide complete visual proof for your assignment:

| # | Screenshot Title | Description & What Must Be Visible |
|---|-------------------|-----------------------------------|
| **1** | **GitHub Repository** | Repository landing page showing `Jenkinsfile`, `Dockerfile`, `k8s/`, and recent commits. |
| **2** | **Jenkins Credentials** | Jenkins Credentials list showing `docker-hub-credentials` ID configured (mask password). |
| **3** | **Pipeline Stage View (Run #1)** | Jenkins Stage View showing green boxes for all 7 stages: *Checkout*, *Lint & Validate*, *Docker Build*, *Test Container*, *Docker Hub Push*, *Kubernetes Deployment*, *Verify Deployment*. |
| **4** | **Docker Hub Repository** | Docker Hub repository `maxspeed2020/toro-transmission` showing the newly pushed tags (`1`, `2`, `latest`). |
| **5** | **Kubernetes Pods & Service CLI** | Terminal executing: <br>`kubectl get deployment toro-transmission`<br>`kubectl get pods -l app=toro-transmission -o wide`<br>`kubectl get svc toro-transmission-service` (Showing 2/2 Replicas, NodePort 30080). |
| **6** | **Live Website in Browser (Run #1)** | Browser tab open at `http://<minikube-ip>:30080` showing the hero section and gear motors. |
| **7** | **Code Commit for Run #2** | Git commit diff or log showing the visible update (`Release v2.0`). |
| **8** | **Pipeline Stage View (Run #2)** | Jenkins Stage View showing Build #2 successfully executed and green. |
| **9** | **Live Website in Browser (Run #2)** | Browser showing the updated page with the visible **"v2.0 (CI/CD Pipeline Run #2)"** hero badge and footer tag. |

---

## 📄 CCA 2 Project Report

### Executive Summary
This project implements an enterprise continuous integration and continuous deployment (CI/CD) pipeline for **Toro Transmission**, a static enterprise web application. Using **Jenkins**, **Docker**, **Docker Hub**, and **Kubernetes (Minikube)**, every code change pushed to the GitHub repository is automatically checked out, linted, compiled into an optimized Nginx container image, smoke-tested, published with dual immutable and latest tags to Docker Hub, and deployed via zero-downtime rolling update to a high-availability Kubernetes cluster with two replicas.

### Technical Specifications
- **Source Code Management**: Git & GitHub (`keepitc00L/toro-transmission-project`)
- **CI/CD Orchestration**: Jenkins Declarative Pipeline (7 Stages)
- **Containerization**: Docker with multi-asset `nginx:1.27-alpine` base image
- **Artifact Registry**: Docker Hub (`maxspeed2020/toro-transmission`)
- **Container Orchestration**: Kubernetes v1.36+ (Minikube)
- **Workload Specifications**: 2 Replicas, RollingUpdate strategy, Liveness/Readiness probes
- **Network Ingress**: Kubernetes `NodePort` Service on port `30080`

### Key Pipeline Stages & Verification Mechanisms
1. **Lint & Validation**: Ensures all required web assets, Nginx configuration, Dockerfile instructions, and Kubernetes YAML manifest schemas exist and conform before containerization.
2. **Docker Build**: Packages assets into a minimal Alpine container, ensuring non-essential artifacts are pruned via `.dockerignore`.
3. **Container Smoke Testing**: Spawns an isolated container instance, validates HTTP 200 response via dynamic polling, verifies content integrity, and uses an exit trap for clean teardown.
4. **Docker Hub Publishing**: Uses masked credentials via Jenkins Credentials Store to authenticate and push versioned and latest tags.
5. **Cluster Pre-Flight & Rolling Deployment**: Verifies cluster connectivity prior to deployment to guard against network boundaries, applies manifests, and triggers a rolling image update.
6. **Health Verification**: Queries the Kubernetes API to assert that exactly 2 out of 2 pods are in `Ready` state and outputs NodePort accessibility endpoints.

### Conclusion & Key Learnings
Automating the deployment of Toro Transmission demonstrates how containerized workloads achieve consistency across development and production environments. The separation of concerns between image creation (Docker Hub) and declarative state reconciliation (Kubernetes) ensures zero-downtime updates and reliable rollback capabilities.
