# CI/CD Practices - Fullstack Homelab

> **Overview**: This document showcases the comprehensive CI/CD practices implemented across my homelab infrastructure, demonstrating enterprise-grade GitOps, automation, and deployment strategies.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [GitHub Actions Workflows](#github-actions-workflows)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Container Image Management](#container-image-management)
- [Kustomize Configuration Management](#kustomize-configuration-management)
- [Infrastructure as Code CI/CD](#infrastructure-as-code-cicd)
- [Deployment Strategies](#deployment-strategies)
- [Testing in CI/CD](#testing-in-cicd)
- [Secrets Management](#secrets-management)
- [Observability & Monitoring](#observability--monitoring)
- [Self-Hosted Runner Infrastructure](#self-hosted-runner-infrastructure)
- [Advanced CI/CD Patterns](#advanced-cicd-patterns)
- [Key Files Reference](#key-files-reference)

---

## Architecture Overview

The CI/CD architecture follows a **GitOps-first** approach with full automation across multiple environments:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Repositories                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │  infra   │ │demo-apps │ │pipelines │ │   cks-   │ │   cks-   │     │
│  │(IaC/Ops) │ │  (Apps)  │ │(Reusable)│ │ frontend │ │ backend  │     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
└───────┼────────────┼────────────┼────────────┼────────────┼───────────┘
        │            │            │            │            │
        └────────────┴────────────┴────────────┴────────────┘
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                 GitHub Actions (Self-Hosted Runners)                     │
│  • Terraform Plan/Apply      • Build & Push Images                      │
│  • Ansible Playbooks          • Kustomize Deployments                    │
│  • Security Scanning          • Cypress Testing                          │
│  • Semantic Releases          • Conventional Commits                     │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
               ┌───────────┴────────────┐
               ▼                        ▼
┌──────────────────────┐    ┌──────────────────────┐
│  Harbor Registry     │    │  ArgoCD GitOps       │
│  (Container Images)  │    │  (Sync Engine)       │
└──────────────────────┘    └─────────┬────────────┘
                                      │
                        ┌─────────────┼─────────────┐
                        ▼             ▼             ▼
                  ┌─────────┐   ┌─────────┐   ┌─────────┐
                  │   Dev   │   │   Stg   │   │  Prod   │
                  │ K8s Env │   │ K8s Env │   │ K8s Env │
                  └─────────┘   └─────────┘   └─────────┘
```

**Core Principles**:
- **Infrastructure as Code**: Everything defined in Git (Terraform, Kustomize, ArgoCD)
- **GitOps**: ArgoCD continuously syncs desired state from Git to Kubernetes
- **Progressive Delivery**: dev → stg → prod with automated testing gates
- **Security First**: SOPS encryption, secret scanning, vulnerability scanning
- **Automated Releases**: Semantic versioning with conventional commits
- **Observability**: OpenTelemetry, health checks, deployment tracking

---

## GitHub Actions Workflows

### Infrastructure Repository Workflows

#### 1. Terraform Plan ([.github/workflows/terraform-plan.yml](infra/.github/workflows/terraform-plan.yml))

**Purpose**: Validates and plans infrastructure changes on pull requests

**Triggers**:
```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'proxmox/**'
      - 'clusters/**'
      - 'secrets/**'
```

**Key Features**:
- **Path-based detection**: Uses `dorny/paths-filter@v3` to detect which infrastructure changed
- **Separate jobs**: Independent Proxmox and Kubernetes cluster planning
- **PR comments**: Posts truncated plan output (65k char limit) directly to PR
- **Artifact uploads**: Stores full plan files for apply phase
- **Makefile integration**: Uses `make init` and `make plan` for cluster workflows
- **Self-hosted runners**: Runs on custom runners with Terraform 1.10.5

**Workflow Extract**:
```yaml
- name: Terraform Plan
  run: terraform plan -out=tfplan
  working-directory: ./proxmox

- name: Upload Plan Artifact
  uses: actions/upload-artifact@v4
  with:
    name: proxmox-plan
    path: proxmox/tfplan
```

#### 2. Terraform Apply ([.github/workflows/terraform-apply.yml](infra/.github/workflows/terraform-apply.yml))

**Purpose**: Automatically applies infrastructure changes after PR merge

**Triggers**:
```yaml
on:
  workflow_run:
    workflows: ["Release"]
    types: [completed]
    branches: [main]
```

**Advanced Features**:
- **Workflow chaining**: Waits for release workflow to complete first
- **Ansible integration**: Extracts `[ansible playbook-name]` from commit messages
- **Auto-inventory update**: Generates Proxmox VM inventory and commits back to repo
- **Automated configuration**: Runs Ansible playbooks on new infrastructure
- **Git automation**: Configures git user and auto-commits inventory updates

**Commit Message Parsing**:
```bash
# Extract ansible playbook from commit message like: [ansible k8s-dev]
PLAYBOOK=$(git log -1 --pretty=%B | grep -oP '\[ansible \K[^\]]+')
```

#### 3. Build & Push ([.github/workflows/build.yml](infra/.github/workflows/build.yml))

**Purpose**: Automatically builds and pushes Docker images when Dockerfiles change

**Key Features**:
- **Smart Dockerfile detection**: Finds all modified Dockerfiles in PR/push
- **Version tagging**: Tags images with `latest` and git tag-based versions
- **Harbor registry**: Pushes to `registry.fullstack.pw/library/`
- **Docker Buildx**: Multi-platform support
- **Filter logic**: Excludes node_modules and hidden directories

**Dynamic Build Matrix**:
```bash
DOCKERFILES=$(find . -type f -name 'Dockerfile' \
  ! -path '*/node_modules/*' ! -path '*/.*' \
  -exec git diff --name-only HEAD~1 HEAD {} + | uniq)
```

#### 4. Ansible Automation ([.github/workflows/ansible.yml](infra/.github/workflows/ansible.yml))

**Purpose**: Commit-driven configuration management

**Trigger Pattern**:
```
Commit message: "feat: deploy k3s cluster [ansible k8s-dev]"
→ Runs ansible/k8s-dev.yml playbook
```

**Intelligence**:
- **K3s cluster detection**: Recognizes `[ansible k8s-<cluster>]` pattern
- **New host targeting**: Validates inventory and limits playbook to new hosts
- **SSH management**: Scans and adds host keys to known_hosts
- **Vault integration**: Uses HashiCorp Vault for secret retrieval

**New Host Detection**:
```bash
ansible-playbook -i ansible/inventory.ini ansible/k8s-dev.yml \
  --limit new_hosts \
  --extra-vars "vault_token=${{ secrets.VAULT_TOKEN }}"
```

#### 5. Security Scanning

##### Trivy Filesystem Scanning ([.github/workflows/sec-trivy.yml](infra/.github/workflows/sec-trivy.yml))

```yaml
- uses: aquasecurity/trivy-action@0.28.0
  with:
    scan-type: 'fs'
    scan-ref: '.'
```

##### TruffleHog Secret Scanning ([.github/workflows/sec-trufflehog.yml](infra/.github/workflows/sec-trufflehog.yml))

```yaml
- uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --only-verified --no-update
```

**Coverage**: Runs on every pull request, full git history scan

#### 6. Conventional Commits ([.github/workflows/conventional-commits.yml](infra/.github/workflows/conventional-commits.yml))

**Purpose**: Enforces commit message standards for automated releases

**Rules**:
- **Allowed types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **Format**: `type(optional-scope): subject`
- **Subject validation**: Must start with lowercase
- **PR validation**: Single commit must match PR title
- **WIP allowance**: Work-in-progress PRs are allowed

**Impact**: Enables semantic-release automation

#### 7. Semantic Release ([.github/workflows/release.yml](infra/.github/workflows/release.yml))

**Purpose**: Automated versioning and changelog generation

**Trigger**: After PR merge to main

**Configuration** ([.releaserc.json](infra/.releaserc.json)):
```json
{
  "branches": ["main"],
  "plugins": [
    ["@semantic-release/commit-analyzer", {
      "releaseRules": [
        {"type": "feat", "release": "minor"},
        {"type": "fix", "release": "patch"},
        {"type": "docs", "release": "patch"},
        {"type": "ci", "release": false},
        {"type": "test", "release": false}
      ]
    }],
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    "@semantic-release/github"
  ]
}
```

**Outputs**:
- Git tags (e.g., v1.2.3)
- GitHub releases with formatted notes
- Automated CHANGELOG.md updates

---

### Demo Apps Repository Workflows

#### 1. Manual Pipeline ([.github/workflows/manual-pipeline.yml](demo-apps/.github/workflows/manual-pipeline.yml))

**Purpose**: Controlled multi-environment deployment with testing gates

**Interface**: Manual workflow dispatch with options:
```yaml
inputs:
  environments:
    type: choice
    options:
      - dev
      - dev,stg
      - dev,stg,prod
  app:
    type: choice
    options:
      - all
      - ascii-frontend
      - enqueuer
      - memorizer
      - writer
  run_tests:
    type: boolean
    default: true
```

**Progressive Delivery**:
```yaml
jobs:
  deploy-dev:
    # Deploys to dev

  test-dev:
    needs: deploy-dev
    if: inputs.run_tests
    # Gates progression to staging

  deploy-stg:
    needs: test-dev
    if: contains(inputs.environments, 'stg')

  test-stg:
    needs: deploy-stg
    # Gates progression to production

  deploy-prod:
    needs: test-stg
    if: contains(inputs.environments, 'prod')
```

**Parallel App Processing**:
```yaml
strategy:
  matrix:
    app: ${{ fromJson(needs.prepare.outputs.apps) }}
  max-parallel: 4
```

**Reusable Workflow Calls**:
```yaml
- uses: fullstack-pw/pipelines/.github/workflows/build-and-push.yml@main
- uses: fullstack-pw/pipelines/.github/workflows/deploy-kustomize.yml@main
- uses: fullstack-pw/pipelines/.github/workflows/cypress.yml@main
```

#### 2. Automatic Pipeline ([.github/workflows/pipeline.yml](demo-apps/.github/workflows/pipeline.yml))

**Status**: Currently commented out (manual control preferred)

**Intelligence**: Detects which apps changed via file paths:
```yaml
paths:
  - 'apps/ascii-frontend/**'
  - 'apps/enqueuer/**'
  - 'apps/memorizer/**'
  - 'apps/writer/**'
```

**Dynamic App Detection**:
```bash
APPS=$(git diff --name-only HEAD~1 HEAD | \
  grep '^apps/' | cut -d'/' -f2 | sort -u | jq -R -s -c 'split("\n")[:-1]')
echo "apps=$APPS" >> $GITHUB_OUTPUT
```

---

### CKS (Certified Kubernetes Security) Applications

The CKS project consists of two applications providing an interactive Kubernetes security learning environment.

#### 1. CKS Frontend ([cks-frontend repository](https://github.com/fullstack-pw/cks-frontend))

**Purpose**: Next.js-based web interface for CKS practice labs

**Technology Stack**:
- Next.js 14 (React with SSR)
- Tailwind CSS 3.3
- xterm.js for browser-based terminal
- SWR for data fetching with caching
- WebSocket for real-time terminal connections

**Dockerfile** ([cks-frontend/Dockerfile](https://github.com/fullstack-pw/cks-frontend/blob/main/Dockerfile)):

```dockerfile
# Stage 1: Dependencies
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Builder
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Stage 3: Production
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
```

**Key Features**:
- Multi-stage build optimization
- Non-root user execution (nextjs:1001)
- Next.js standalone output for minimal image size
- Production-optimized with telemetry disabled

**Kustomize Structure**:
```
cks-frontend/kustomize/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml          # 1 replica, port 3000
│   ├── service.yaml             # ClusterIP service
│   ├── virtualservice.yaml      # Istio routing
│   └── configmap.yaml           # Environment config
└── overlays/
    ├── dev/                     # dev.cks.fullstack.pw
    ├── stg/                     # stg.cks.fullstack.pw
    └── prod/                    # cks.fullstack.pw
```

**Deployment Configuration**:
```yaml
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: cks-frontend
        image: registry.fullstack.pw/library/cks-frontend:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 20
```

**CI/CD Pipeline** ([.github/workflows/pipeline.yml](https://github.com/fullstack-pw/cks-frontend/blob/main/.github/workflows/pipeline.yml)):

```yaml
name: Build and Deploy

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  docker-build-and-push:
    uses: fullstack-pw/pipelines/.github/workflows/build-and-push.yml@main
    with:
      app_name: cks-frontend
      context: .
      dockerfile: Dockerfile
    secrets:
      HARBOR_KEY: ${{ secrets.HARBOR_KEY }}

  dev-deploy:
    needs: docker-build-and-push
    if: github.event_name == 'push'
    uses: fullstack-pw/pipelines/.github/workflows/deploy-kustomize.yml@main
    with:
      app_name: cks-frontend
      environment: dev
      image_tag: ${{ github.sha }}
      kustomize_path: ./kustomize/overlays/dev
      context: dev
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG }}

  versioning:
    needs: dev-deploy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ietf-tools/semver-action@v1
      - uses: ncipollo/release-action@v1.12.0
```

**Manual Deployment** ([.github/workflows/manual-pipeline.yml](https://github.com/fullstack-pw/cks-frontend/blob/main/.github/workflows/manual-pipeline.yml)):

```yaml
on:
  workflow_dispatch:
    inputs:
      deploy_target:
        type: choice
        options:
          - dev
          - stg
          - prod
      run_tests:
        type: boolean
        default: true
```

**Environment Variables**:
```yaml
ENVIRONMENT: dev
LOG_LEVEL: DEBUG
API_BASE_URL: https://dev.api.cks.fullstack.pw/api/v1
NODE_ENV: production
NEXT_TELEMETRY_DISABLED: 1
```

**Makefile Commands**:
```makefile
build:        # Build Docker image
push:         # Push to registry
dev:          # Start development server (npm run dev)
deploy:       # Deploy to Kubernetes with kustomize
run:          # Run container locally
logs:         # View application logs
port-forward: # Port forward service to localhost:3000
```

#### 2. CKS Backend ([cks-backend repository](https://github.com/fullstack-pw/cks-backend))

**Purpose**: Go-based REST API backend for lab session management

**Technology Stack**:
- Go 1.24
- Gin web framework 1.10
- k8s.io/client-go v0.31.8 (Kubernetes client)
- kubevirt client v1.5.0 (VM management)
- gorilla/websocket v1.5.4 (terminal sessions)
- creack/pty v1.1.24 (PTY handling)
- prometheus/client_golang v1.19.1 (metrics)

**Dockerfile** ([cks-backend/Dockerfile](https://github.com/fullstack-pw/cks-backend/blob/main/Dockerfile)):

```dockerfile
# Stage 1: Builder
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags='-w -s -extldflags "-static"' \
    -o server ./cmd/server

# Stage 2: Runtime
FROM alpine:3.19
RUN apk add --no-cache ca-certificates curl kubectl openssh

# Install virtctl for KubeVirt management
RUN curl -L -o /usr/local/bin/virtctl \
    https://github.com/kubevirt/kubevirt/releases/download/v1.5.1/virtctl-v1.5.1-linux-amd64 && \
    chmod +x /usr/local/bin/virtctl

RUN adduser -D -u 1001 appuser
WORKDIR /app
COPY --from=builder /app/server .
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/scenarios ./scenarios

RUN mkdir -p /home/appuser/.ssh && \
    chown -R appuser:appuser /home/appuser

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./server"]
```

**Key Features**:
- Static Go binary compilation
- Alpine-based runtime (~50MB)
- KubeVirt virtctl CLI pre-installed
- kubectl for Kubernetes operations
- Non-root user execution (appuser:1001)
- Health check endpoint built-in

**Kustomize Structure**:
```
cks-backend/kustomize/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml          # 1 replica, port 8080
│   ├── service.yaml             # ClusterIP service
│   ├── virtualservice.yaml      # Istio routing with retries
│   └── configmap.yaml           # Extensive configuration
└── overlays/
    ├── dev/                     # dev.api.cks.fullstack.pw
    ├── stg/                     # stg.api.cks.fullstack.pw
    └── prod/                    # api.cks.fullstack.pw
```

**Deployment Configuration**:
```yaml
spec:
  replicas: 1
  template:
    spec:
      securityContext:
        fsGroup: 1001

      initContainers:
      - name: setup-ssh
        image: alpine:3.19
        command: ["/bin/sh", "-c"]
        args:
          - |
            cp /secrets/ssh-key /ssh-setup/id_rsa
            cp /secrets/ssh-key.pub /ssh-setup/id_rsa.pub
            chmod 600 /ssh-setup/id_rsa
            chmod 644 /ssh-setup/id_rsa.pub
            touch /ssh-setup/known_hosts
            chmod 644 /ssh-setup/known_hosts
        volumeMounts:
        - name: ssh-secrets
          mountPath: /secrets
        - name: ssh-key-setup
          mountPath: /ssh-setup

      containers:
      - name: cks-backend
        image: registry.fullstack.pw/library/cks-backend:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        volumeMounts:
        - name: kubeconfig
          mountPath: /etc/kubeconfig
          readOnly: true
        - name: ssh-key-setup
          mountPath: /home/appuser/.ssh
        env:
        - name: KUBECONFIG
          value: /etc/kubeconfig/KUBECONFIG
        envFrom:
        - configMapRef:
            name: cks-backend-config
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20

      volumes:
      - name: kubeconfig
        secret:
          secretName: kubeconfig
      - name: ssh-secrets
        secret:
          secretName: ssh-key
      - name: ssh-key-setup
        emptyDir: {}
```

**Advanced Features**:
- **Init container**: Sets up SSH keys with proper permissions before app starts
- **Security context**: fsGroup 1001 ensures proper file ownership
- **Multiple volume mounts**: kubeconfig, SSH keys
- **ConfigMap injection**: Extensive environment configuration
- **Health endpoints**: Ready and live probes on /health

**ConfigMap Configuration**:
```yaml
data:
  ENVIRONMENT: dev
  LOG_LEVEL: DEBUG
  SERVER_PORT: "8080"
  KUBERNETES_CONTEXT: sandboxy
  KUBERNETES_VERSION: 1.33.0
  VM_CPU_CORES: "2"
  VM_MEMORY: 2Gi
  VM_STORAGE_SIZE: 10Gi
  VM_STORAGE_CLASS: longhorn
  POD_CIDR: 10.0.0.0/8
  GOLDEN_IMAGE_NAME: new-golden-image-1-33-0
  GOLDEN_IMAGE_NAMESPACE: vm-templates
  VALIDATE_GOLDEN_IMAGE: "true"
  TEMPLATE_PATH: /app/templates
  SCENARIOS_PATH: /app/scenarios
```

**Istio VirtualService** (with retry logic):
```yaml
spec:
  hosts:
  - dev.api.cks.fullstack.pw
  gateways:
  - istio-system/default-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: cks-backend.default.svc.cluster.local
        port:
          number: 8080
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: 5xx,reset,connect-failure,refused-stream
```

**CI/CD Pipeline**:
- Same structure as frontend
- Uses reusable workflows from fullstack-pw/pipelines
- Automatic deployment to dev on push to main
- Manual deployment option for stg/prod
- Semantic versioning with GitHub releases

**Project Structure**:
```
src/
├── cmd/server/main.go                    # Entry point
├── internal/
│   ├── config/config.go                  # Configuration
│   ├── controllers/                      # HTTP handlers
│   │   ├── scenario_controller.go
│   │   ├── session_controller.go
│   │   ├── terminal_controller.go
│   │   └── admin_controller.go
│   ├── services/                         # Business logic
│   │   ├── scenario_service.go
│   │   ├── session_service.go
│   │   └── terminal_service.go
│   ├── sessions/session_manager.go       # Session lifecycle
│   ├── scenarios/scenario_manager.go     # Scenario management
│   ├── validation/unified_validator.go   # Task validation
│   ├── terminal/terminal_manager.go      # WebSocket terminal
│   ├── kubevirt/client.go                # KubeVirt integration
│   ├── clusterpool/manager.go            # Cluster pooling
│   └── middleware/middleware.go          # CORS, logging
├── scenarios/                            # Lab scenarios
│   ├── categories.yaml
│   ├── basic-pod-security/
│   ├── kubectl-contexts/
│   └── falco-runtime-security/
└── templates/                            # K8s templates
    ├── control-plane-template.yaml
    ├── worker-node-template.yaml
    └── cloud-config templates
```

**API Endpoints**:
- `GET /health` - Health check
- `GET /api/v1/scenarios` - List scenarios
- `POST /api/v1/sessions` - Create lab session
- `GET /api/v1/sessions/:id` - Get session details
- `WS /api/v1/terminal/:id` - WebSocket terminal
- `POST /api/v1/validate` - Validate task completion

#### CKS Applications Summary

**Integration Points**:
- Frontend calls backend API via HTTPS
- Backend provisions KubeVirt VMs for lab environments
- WebSocket connections for real-time terminal access
- Istio service mesh for traffic management
- Both apps deployed via GitHub Actions + Kustomize

**Security Practices**:
- Non-root container execution (UID 1001)
- SSH key management via init containers
- Kubernetes secrets for sensitive data
- CORS configured for API security
- Health checks for high availability
- Resource limits for stability

**Deployment Flow**:
```
Code Push → GitHub Actions → Docker Build → Harbor Registry
                                  ↓
                         Kustomize Apply → K8s Cluster
                                  ↓
                         Health Checks → Service Ready
```

**Future Enhancement**: ArgoCD GitOps integration (not yet configured)

---

### Reusable Workflows Library

Repository: `fullstack-pw/pipelines`

#### 1. Build and Push ([pipelines/.github/workflows/build-and-push.yml](https://github.com/fullstack-pw/pipelines))

**Interface**:
```yaml
workflow_call:
  inputs:
    app_name: { required: true, type: string }
    context: { required: true, type: string }
    dockerfile: { required: true, type: string }
  secrets:
    HARBOR_KEY: { required: true }
```

**Process**:
1. Docker Buildx setup
2. Harbor registry login
3. Build with context path
4. Tag: `registry.fullstack.pw/library/{app}:{sha}` + `latest`
5. Push to registry

#### 2. Deploy Kustomize ([pipelines/.github/workflows/deploy-kustomize.yml](https://github.com/fullstack-pw/pipelines))

**Interface**:
```yaml
workflow_call:
  inputs:
    app_name: { required: true }
    environment: { required: true }
    image_tag: { required: true }
    kustomize_path: { required: true }
    context: { required: true }
```

**Process**:
1. Switch kubectl context
2. Replace `latest` with commit SHA in kustomization
3. Render manifest for visibility
4. Apply with kubectl
5. Wait for rollout completion (5min timeout)

**Rollout Verification**:
```bash
kubectl rollout status deployment/${{ inputs.app_name }} \
  -n ${{ inputs.app_name }} \
  --timeout=5m
```

#### 3. Cypress Testing ([pipelines/.github/workflows/cypress.yml](https://github.com/fullstack-pw/pipelines))

**Container**: `cypress/included:latest`

**Dynamic Environment Variables**:
```yaml
inputs:
  env_vars:
    type: string
    default: '{"CYPRESS_BASE_URL":"http://example.com"}'
```

**Node.js Injection**:
```javascript
// inject-env.js
const envVars = JSON.parse(process.env.ENV_VARS_JSON);
Object.entries(envVars).forEach(([key, value]) => {
  process.env[key] = value;
});
```

**Test Execution**:
```yaml
- uses: cypress-io/github-action@v6
  with:
    browser: chrome
    record: false
    config: video=false,screenshotOnRunFailure=false
```

#### 4. Go Tests ([pipelines/.github/workflows/go-tests.yml](https://github.com/fullstack-pw/pipelines))

**Steps**:
1. Go setup (latest stable)
2. `go mod tidy` - Dependency cleanup
3. `go test ./... -v` - Unit tests
4. `golangci-lint run` - Static analysis

---

## GitOps with ArgoCD

### App-of-Apps Pattern

**Parent Application** ([argocd-apps/app-of-apps/dev-apps.yaml](infra/argocd-apps/app-of-apps/dev-apps.yaml)):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/fullstack-pw/infra
    targetRevision: HEAD
    path: argocd-apps/app-of-apps/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Benefits**:
- Single source of truth for all applications
- Automated child app creation/deletion
- Centralized sync policies
- GitOps for GitOps configuration

### Individual Application Configuration

**Example** ([argocd-apps/app-of-apps/dev/writer.yaml](infra/argocd-apps/app-of-apps/dev/writer.yaml)):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: writer-dev
spec:
  project: default
  source:
    repoURL: https://github.com/fullstack-pw/demo-apps
    targetRevision: HEAD
    path: apps/writer/kustomize/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: writer
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Key Features**:
- **Automated sync**: Changes in Git auto-deploy to cluster
- **Self-healing**: Reverts manual cluster changes
- **Pruning**: Removes resources deleted from Git
- **Retry logic**: Exponential backoff on failures (5s → 10s → 20s → 40s → 3m)

### Sync Waves and Hooks

**Demo Application** ([argocd-apps/sync-waves-demo.yaml](infra/argocd-apps/sync-waves-demo.yaml)):

**Sync Wave Ordering**:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # ConfigMaps deploy first
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # Default resources
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Final resources
```

**Hooks**:
```yaml
# PreSync Hook - Runs before sync starts
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
      - name: pre-sync-job
        image: alpine:latest
        command: ["echo", "Running pre-sync validation"]

# PostSync Hook - Runs after successful sync
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
```

**Use Cases**:
- Database migrations (PreSync)
- Cache warming (PostSync)
- Secret creation before deployments
- Validation jobs

### ArgoCD Infrastructure (Terraform)

**Module Configuration** ([clusters/modules.tf](infra/clusters/modules.tf)):

```hcl
module "argocd" {
  source  = "terraform-module/release/helm"
  version = "7.7.12"

  namespace = {
    name   = "argocd"
    create = true
  }

  app = {
    name          = "argocd"
    version       = "7.7.12"
    chart         = "argo-cd"
    repository    = "https://argoproj.github.io/argo-helm"
    recreate_pods = true
  }

  values = [templatefile("${path.module}/argocd-values.yaml", {
    istio_enabled = true
    notifications_enabled = true
  })]

  set = [
    {
      name  = "controller.args.applicationNamespaces"
      value = "*"
    }
  ]
}
```

**Integrations**:
- Istio service mesh
- Cert-manager for TLS
- Notifications (Slack/email)
- All-namespace application support

---

## Container Image Management

### Multi-Stage Build Pattern

**Go Application Example** ([demo-apps/apps/writer/Dockerfile](demo-apps/apps/writer/Dockerfile)):

```dockerfile
# Stage 1: Builder
FROM golang:1.23.1-alpine AS builder

WORKDIR /app

# Copy dependency files first (layer caching optimization)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Stage 2: Runtime
FROM alpine:3.19

# Install CA certificates for HTTPS
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /root/

# Copy only the binary from builder
COPY --from=builder /app/main .

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["./main"]
```

**Optimization Techniques**:
- **Layer caching**: go.mod/go.sum copied separately
- **Static linking**: CGO_ENABLED=0 for portability
- **Minimal runtime**: Alpine Linux (~5MB base)
- **Security**: CA certs for secure connections
- **Health checks**: Built-in container health validation

### Infrastructure Component Example

**GitHub Runner Image** ([infra/modules/apps/github-runner/Dockerfile](infra/modules/apps/github-runner/Dockerfile)):

```dockerfile
FROM ghcr.io/actions/actions-runner:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform (HashiCorp official repo)
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt update && apt install terraform

# Install SOPS and age for secret management
RUN wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 \
    -O /usr/local/bin/sops && chmod +x /usr/local/bin/sops
RUN wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz \
    && tar -xzf age-*.tar.gz && mv age/age /usr/local/bin/

# Install Docker CLI
RUN apt-get update && apt-get install -y docker.io

# Install Python tools
RUN pip3 install ansible hvac kubernetes boto3

# Shell completion
RUN kubectl completion bash > /etc/bash_completion.d/kubectl && \
    helm completion bash > /etc/bash_completion.d/helm

ENV DOCKER_BUILDKIT=1
```

**Pre-installed Tooling**:
- Kubernetes: kubectl + Helm
- IaC: Terraform + Ansible
- Security: SOPS + age encryption
- Container: Docker CLI
- Python: Cloud SDKs (AWS/Azure/GCP support)

### Image Tagging Strategy

**Pattern**:
```
registry.fullstack.pw/library/{app}:latest
registry.fullstack.pw/library/{app}:{git-sha}
registry.fullstack.pw/library/{app}:{git-tag}  # For releases
```

**Rationale**:
- **latest**: Convenience for development/testing
- **git-sha**: Immutable, traceable to exact code version
- **git-tag**: Semantic versions for releases (v1.2.3)

**Example Workflow**:
```yaml
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    push: true
    tags: |
      registry.fullstack.pw/library/${{ inputs.app_name }}:latest
      registry.fullstack.pw/library/${{ inputs.app_name }}:${{ github.sha }}
```

---

## Kustomize Configuration Management

### Directory Structure

**Standard App Layout**:
```
apps/{app-name}/
├── Dockerfile
├── main.go / package.json
├── kustomize/
│   ├── base/
│   │   ├── kustomization.yaml       # Base resource list
│   │   ├── deployment.yaml          # Common deployment spec
│   │   ├── service.yaml             # ClusterIP service
│   │   └── virtualservice.yaml      # Istio routing (if applicable)
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml   # Dev-specific patches
│       ├── stg/
│       │   └── kustomization.yaml   # Staging patches
│       └── prod/
│           └── kustomization.yaml   # Production patches
```

### Base Configuration

**Base Kustomization** ([demo-apps/apps/writer/kustomize/base/kustomization.yaml](demo-apps/apps/writer/kustomize/base/kustomization.yaml)):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - virtualservice.yaml

commonLabels:
  app: writer
  managed-by: kustomize
```

**Base Deployment** ([demo-apps/apps/writer/kustomize/base/deployment.yaml](demo-apps/apps/writer/kustomize/base/deployment.yaml)):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writer
  namespace: writer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: writer
  template:
    metadata:
      labels:
        app: writer
        version: v1
    spec:
      containers:
      - name: writer
        image: registry.fullstack.pw/library/writer:latest
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: writer-secrets
              key: rabbitmq-url
        - name: QUEUE_NAME
          value: "events"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "opentelemetry-collector.observability.svc.cluster.local:4317"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
```

**Base Service** ([demo-apps/apps/writer/kustomize/base/service.yaml](demo-apps/apps/writer/kustomize/base/service.yaml)):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: writer
  namespace: writer
spec:
  selector:
    app: writer
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: ClusterIP
```

**Istio VirtualService** ([demo-apps/apps/writer/kustomize/base/virtualservice.yaml](demo-apps/apps/writer/kustomize/base/virtualservice.yaml)):

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: writer
  namespace: writer
spec:
  hosts:
  - writer.example.com  # Overridden in overlays
  gateways:
  - istio-system/default-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: writer.writer.svc.cluster.local
        port:
          number: 8080
```

### Environment Overlays

**Dev Overlay** ([demo-apps/apps/writer/kustomize/overlays/dev/kustomization.yaml](demo-apps/apps/writer/kustomize/overlays/dev/kustomization.yaml)):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: writer

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: writer
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: registry.fullstack.pw/library/writer:latest
      - op: replace
        path: /spec/strategy
        value:
          type: RollingUpdate
          rollingUpdate:
            maxSurge: 100%
            maxUnavailable: 50%
      - op: replace
        path: /spec/template/spec/containers/0/env/1/value
        value: "events-dev"

  - target:
      kind: VirtualService
      name: writer
    patch: |-
      - op: replace
        path: /spec/hosts/0
        value: writer-dev.fullstack.pw
```

**Overlay Features**:
- **Replica adjustment**: 1 replica in dev, more in prod
- **Aggressive rolling updates**: Faster deployments in dev (maxSurge: 100%)
- **Environment-specific config**: Queue names, hostnames
- **Image tag control**: Dev uses `latest`, prod uses SHA

**Staging Overlay Pattern**:
```yaml
# Similar to dev but:
- replicas: 2
- maxSurge: 1, maxUnavailable: 0  # Zero-downtime deployments
- queue: "events-stg"
- host: "writer-stg.fullstack.pw"
```

**Production Overlay Pattern**:
```yaml
# Production hardening:
- replicas: 3
- maxSurge: 1, maxUnavailable: 0  # Conservative updates
- queue: "events-prod"
- host: "writer.fullstack.pw"
- Resource limits increased
- PodDisruptionBudget added
```

### Kustomize in CI/CD

**Deployment Workflow Usage**:
```bash
# Replace image tag in overlay
cd ${{ inputs.kustomize_path }}
kustomize edit set image \
  registry.fullstack.pw/library/${{ inputs.app_name }}:latest=\
  registry.fullstack.pw/library/${{ inputs.app_name }}:${{ inputs.image_tag }}

# Render final manifest
kubectl kustomize . > /tmp/manifest.yaml
cat /tmp/manifest.yaml  # Show what will be applied

# Apply to cluster
kubectl apply -k .
```

**Benefits**:
- **DRY**: Base config shared across environments
- **Traceable**: Git shows exact differences between environments
- **Type-safe**: Kubernetes validates manifests
- **No templating**: Pure YAML, no Helm complexity

---

## Infrastructure as Code CI/CD

### Terraform Workflow Automation

**Makefile-Driven Infrastructure** ([infra/Makefile](infra/Makefile)):

```makefile
.PHONY: plan apply destroy validate fmt

# Variables
WORKSPACE ?= dev
TF_DIR = clusters

# Initialize Terraform with workspace
init:
  cd $(TF_DIR) && \
  terraform init && \
  terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE)

# Plan infrastructure changes
plan: init decrypt-secrets
  cd $(TF_DIR) && \
  terraform plan -out=tfplan

# Apply infrastructure changes
apply: init decrypt-secrets
  cd $(TF_DIR) && \
  terraform apply tfplan

# Destroy infrastructure (with confirmation)
destroy: init decrypt-secrets
  cd $(TF_DIR) && \
  terraform destroy

# Validate Terraform files
validate:
  cd $(TF_DIR) && \
  terraform fmt -recursive && \
  terraform validate

# Format Terraform files
fmt:
  terraform fmt -recursive

# Decrypt secrets using SOPS
decrypt-secrets:
  @echo "Decrypting secrets with SOPS..."
  cd $(TF_DIR) && python3 load_secrets.py
```

**Multi-Workspace Strategy**:
```bash
# Separate state per environment
make plan WORKSPACE=dev      # Development cluster
make plan WORKSPACE=stg      # Staging cluster
make plan WORKSPACE=prod     # Production cluster
make plan WORKSPACE=tools    # Tooling cluster (ArgoCD, Harbor, etc.)
```

### Secret Loading Automation

**SOPS Secret Loader** ([infra/clusters/load_secrets.py](infra/clusters/load_secrets.py)):

```python
#!/usr/bin/env python3
import subprocess
import json
import yaml
import os
from pathlib import Path

def decrypt_sops_file(file_path):
    """Decrypt a SOPS-encrypted file"""
    try:
        result = subprocess.run(
            ['sops', '-d', file_path],
            capture_output=True,
            text=True,
            check=True
        )
        return yaml.safe_load(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting {file_path}: {e}")
        return {}

def flatten_dict(d, parent_key='', sep='_'):
    """Flatten nested dictionary structure"""
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def main():
    secrets_dir = Path('../secrets')
    combined_secrets = {}

    # Load common secrets
    common_secrets = secrets_dir / 'common' / 'secrets.yaml'
    if common_secrets.exists():
        data = decrypt_sops_file(common_secrets)
        combined_secrets.update(flatten_dict(data))

    # Load environment-specific secrets
    workspace = os.getenv('TF_WORKSPACE', 'dev')
    env_secrets = secrets_dir / workspace / 'secrets.yaml'
    if env_secrets.exists():
        data = decrypt_sops_file(env_secrets)
        combined_secrets.update(flatten_dict(data))

    # Write combined secrets to JSON
    with open('secrets.json', 'w') as f:
        json.dump(combined_secrets, f, indent=2)

    print(f"Loaded {len(combined_secrets)} secrets for workspace: {workspace}")

if __name__ == '__main__':
    main()
```

**Usage in Terraform**:
```hcl
locals {
  secrets = jsondecode(file("${path.module}/secrets.json"))
}

module "kubernetes" {
  source = "./modules/kubernetes"

  vault_token = local.secrets["vault_token"]
  harbor_password = local.secrets["harbor_password"]
}
```

### Terraform Backend Configuration

**Remote State** ([infra/clusters/backend.tf](infra/clusters/backend.tf)):

```hcl
terraform {
  backend "s3" {
    bucket = "fullstack-terraform-state"
    key    = "clusters/terraform.tfstate"
    region = "us-east-1"

    # Workspace prefix for environment isolation
    workspace_key_prefix = "env"

    # State locking with DynamoDB
    dynamodb_table = "terraform-state-lock"

    encrypt = true
  }
}
```

**State Isolation**:
```
s3://fullstack-terraform-state/
├── env/dev/clusters/terraform.tfstate
├── env/stg/clusters/terraform.tfstate
├── env/prod/clusters/terraform.tfstate
└── env/tools/clusters/terraform.tfstate
```

### CI/CD Integration

**Plan Phase** (Pull Request):
```yaml
- name: Terraform Init
  run: make init WORKSPACE=dev

- name: Terraform Plan
  run: make plan WORKSPACE=dev

- name: Comment Plan on PR
  run: |
    PLAN_OUTPUT=$(terraform -chdir=clusters show -no-color tfplan)
    gh pr comment ${{ github.event.pull_request.number }} \
      --body "### Terraform Plan (dev)

    \`\`\`
    ${PLAN_OUTPUT:0:65000}
    \`\`\`"
```

**Apply Phase** (After Merge):
```yaml
- name: Download Plan Artifact
  uses: actions/download-artifact@v4
  with:
    name: dev-plan
    path: clusters/

- name: Terraform Apply
  run: |
    cd clusters
    terraform workspace select dev
    terraform apply tfplan
```

**Inventory Auto-Update**:
```yaml
- name: Update Ansible Inventory
  run: |
    cd proxmox
    terraform output -json vm_ips > ../ansible/inventory.json
    python3 generate_inventory.py

- name: Commit Updated Inventory
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git add ansible/inventory.ini
    git commit -m "chore: update ansible inventory [skip ci]"
    git push
```

---

## Deployment Strategies

### Rolling Updates

**Default Strategy** (Dev Environment):
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 100%        # Can create 100% more pods during update
      maxUnavailable: 50%   # Up to 50% can be unavailable
```

**Progressive Strategy** (Staging):
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Only 1 extra pod at a time
      maxUnavailable: 0     # Zero downtime
```

**Conservative Strategy** (Production):
```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Gradual rollout
      maxUnavailable: 0     # No downtime allowed

  # Additional production safeguards
  minReadySeconds: 30       # Wait 30s before marking pod ready
```

**Update Flow**:
```
Initial State: [Pod1] [Pod2] [Pod3]
Step 1: Create new pod → [Pod1] [Pod2] [Pod3] [Pod4-new]
Step 2: Wait for Pod4 readiness
Step 3: Terminate Pod1 → [Pod2] [Pod3] [Pod4-new]
Step 4: Create Pod5 → [Pod2] [Pod3] [Pod4-new] [Pod5-new]
...continues until all pods updated
```

### Health Checks & Rollback

**Readiness Probe** (Prevents traffic to unhealthy pods):
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
    httpHeaders:
    - name: Accept
      value: application/json
  initialDelaySeconds: 5    # Wait 5s after container start
  periodSeconds: 10         # Check every 10s
  timeoutSeconds: 3         # Request timeout
  successThreshold: 1       # 1 success = ready
  failureThreshold: 3       # 3 failures = not ready
```

**Liveness Probe** (Restarts unhealthy pods):
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15   # Give app time to start
  periodSeconds: 20         # Check every 20s
  timeoutSeconds: 5
  failureThreshold: 3       # 3 failures = restart pod
```

**Health Endpoint Implementation** (Go):
```go
func healthHandler(w http.ResponseWriter, r *http.Request) {
    // Check dependencies
    if !isRabbitMQConnected() {
        w.WriteHeader(http.StatusServiceUnavailable)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "unhealthy",
            "reason": "rabbitmq disconnected",
        })
        return
    }

    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
    })
}
```

**Rollout Verification in CI/CD**:
```bash
# Wait for rollout to complete (5 minute timeout)
kubectl rollout status deployment/writer -n writer --timeout=5m

# Check rollout status
if [ $? -ne 0 ]; then
  echo "Deployment failed, rolling back..."
  kubectl rollout undo deployment/writer -n writer
  exit 1
fi

# Verify pod health
kubectl wait --for=condition=ready pod \
  -l app=writer \
  -n writer \
  --timeout=300s
```

**Automatic Rollback** (GitOps):
```yaml
# ArgoCD auto-sync will revert bad deployments
syncPolicy:
  automated:
    prune: true
    selfHeal: true  # Reverts manual changes

  # Retry failed syncs with backoff
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Progressive Delivery

**Multi-Environment Pipeline**:

```
┌─────────────────────────────────────────────────────────────┐
│                         Deployment Flow                       │
└─────────────────────────────────────────────────────────────┘

1. Build & Push Image
   ↓
2. Deploy to DEV
   ├─ Kustomize overlay: aggressive rolling update
   ├─ Replicas: 1
   └─ Image tag: latest → commit-sha
   ↓
3. Test DEV (Cypress)
   ├─ Smoke tests
   ├─ API integration tests
   └─ E2E scenarios
   ↓
   GATE: Tests must pass
   ↓
4. Deploy to STAGING
   ├─ Kustomize overlay: zero-downtime updates
   ├─ Replicas: 2
   └─ Production-like config
   ↓
5. Test STAGING (Cypress)
   ├─ Full regression suite
   ├─ Performance tests
   └─ Load testing
   ↓
   GATE: Tests + Manual approval
   ↓
6. Deploy to PRODUCTION
   ├─ Kustomize overlay: conservative rolling update
   ├─ Replicas: 3+
   ├─ PodDisruptionBudget
   └─ Enhanced monitoring
   ↓
7. Test PRODUCTION (Cypress)
   ├─ Smoke tests only
   └─ Real user monitoring
```

**GitHub Actions Implementation**:
```yaml
jobs:
  deploy-dev:
    runs-on: self-hosted
    steps:
      - uses: fullstack-pw/pipelines/.github/workflows/deploy-kustomize.yml@main
        with:
          environment: dev

  test-dev:
    needs: deploy-dev
    runs-on: ubuntu-latest
    steps:
      - uses: fullstack-pw/pipelines/.github/workflows/cypress.yml@main
        with:
          env_vars: '{"CYPRESS_BASE_URL":"https://app-dev.fullstack.pw"}'

  deploy-stg:
    needs: test-dev
    if: contains(github.event.inputs.environments, 'stg')
    # ... similar pattern

  deploy-prod:
    needs: test-stg
    if: contains(github.event.inputs.environments, 'prod')
    environment: production  # Requires manual approval in GitHub
```

**Environment-Specific Gates**:
- **Dev**: Automatic deployment on merge
- **Staging**: Automatic after dev tests pass
- **Production**: Manual approval required

---

## Testing in CI/CD

### Unit Testing (Go)

**Workflow** ([pipelines/.github/workflows/go-tests.yml](https://github.com/fullstack-pw/pipelines)):

```yaml
name: Go Tests

on:
  workflow_call:
    inputs:
      working_directory:
        required: true
        type: string

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: 'stable'

      - name: Tidy dependencies
        run: go mod tidy
        working-directory: ${{ inputs.working_directory }}

      - name: Run tests
        run: go test ./... -v -race -coverprofile=coverage.out
        working-directory: ${{ inputs.working_directory }}

      - name: Generate coverage report
        run: go tool cover -html=coverage.out -o coverage.html

      - name: Lint code
        uses: golangci/golangci-lint-action@v6
        with:
          working-directory: ${{ inputs.working_directory }}
```

**Example Test** (Go):
```go
func TestHealthEndpoint(t *testing.T) {
    req, _ := http.NewRequest("GET", "/health", nil)
    rr := httptest.NewRecorder()

    handler := http.HandlerFunc(healthHandler)
    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status code: got %v want %v",
            status, http.StatusOK)
    }

    expected := `{"status":"healthy"}`
    if rr.Body.String() != expected {
        t.Errorf("handler returned unexpected body: got %v want %v",
            rr.Body.String(), expected)
    }
}
```

### Integration Testing (Cypress)

**Configuration** ([demo-apps/cypress.config.js](demo-apps/cypress.config.js)):

```javascript
const { defineConfig } = require('cypress');

module.exports = defineConfig({
  e2e: {
    baseUrl: process.env.CYPRESS_BASE_URL || 'http://localhost:3000',

    setupNodeEvents(on, config) {
      // Custom tasks for complex operations
      on('task', {
        resetTestState() {
          // Reset database or state between tests
          return null;
        },

        simulateServiceRestart() {
          // Chaos engineering scenarios
          return null;
        },

        queryOpenTelemetryTraces(traceId) {
          // Validate observability data
          return { spans: [], duration: 0 };
        },
      });

      return config;
    },

    retries: {
      runMode: 2,      // Retry failed tests 2 times in CI
      openMode: 0,     // No retries in interactive mode
    },

    video: false,      // Disable video recording for faster tests
    screenshotOnRunFailure: false,

    defaultCommandTimeout: 10000,
    responseTimeout: 30000,

    env: {
      environment: process.env.ENVIRONMENT || 'dev',
    },
  },

  reporter: 'mochawesome',
  reporterOptions: {
    reportDir: 'cypress/results',
    overwrite: false,
    html: true,
    json: true,
  },
});
```

**Test Example** ([demo-apps/cypress/e2e/enqueuer.cy.js](demo-apps/cypress/e2e/enqueuer.cy.js)):

```javascript
describe('Enqueuer Service', () => {
  beforeEach(() => {
    cy.task('resetTestState');
  });

  it('should enqueue a message successfully', () => {
    cy.request({
      method: 'POST',
      url: `${Cypress.env('ENQUEUER_URL')}/api/enqueue`,
      body: {
        url: 'https://example.com',
        priority: 'high',
      },
    }).then((response) => {
      expect(response.status).to.eq(200);
      expect(response.body).to.have.property('messageId');
      expect(response.body.status).to.eq('queued');
    });
  });

  it('should handle invalid URLs gracefully', () => {
    cy.request({
      method: 'POST',
      url: `${Cypress.env('ENQUEUER_URL')}/api/enqueue`,
      body: { url: 'not-a-valid-url' },
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(400);
      expect(response.body.error).to.include('Invalid URL');
    });
  });

  it('should verify message appears in queue', () => {
    const testUrl = 'https://test-' + Date.now() + '.com';

    // Enqueue message
    cy.request('POST', `${Cypress.env('ENQUEUER_URL')}/api/enqueue`, {
      url: testUrl,
    }).then((enqueueResponse) => {
      const messageId = enqueueResponse.body.messageId;

      // Verify in queue
      cy.request('GET', `${Cypress.env('ENQUEUER_URL')}/api/queue/status`)
        .then((statusResponse) => {
          expect(statusResponse.body.messages).to.include(messageId);
        });
    });
  });
});
```

**End-to-End Pipeline Test** ([demo-apps/cypress/e2e/full-pipeline.cy.js](demo-apps/cypress/e2e/full-pipeline.cy.js)):

```javascript
describe('Full Pipeline E2E', () => {
  it('should process URL from enqueue to storage', () => {
    const testUrl = 'https://example.com/test-' + Date.now();
    let messageId;

    // Step 1: Enqueue URL
    cy.request('POST', `${Cypress.env('ENQUEUER_URL')}/api/enqueue`, {
      url: testUrl,
    }).then((response) => {
      messageId = response.body.messageId;
      expect(messageId).to.exist;
    });

    // Step 2: Wait for processing (with retry)
    cy.wait(5000);
    cy.request('GET', `${Cypress.env('WRITER_URL')}/api/status/${messageId}`)
      .then((response) => {
        expect(response.body.status).to.be.oneOf(['processing', 'completed']);
      });

    // Step 3: Verify stored in Memorizer
    cy.wait(10000);
    cy.request('GET', `${Cypress.env('MEMORIZER_URL')}/api/urls`)
      .then((response) => {
        const storedUrls = response.body.map(item => item.url);
        expect(storedUrls).to.include(testUrl);
      });

    // Step 4: Validate OpenTelemetry traces
    cy.task('queryOpenTelemetryTraces', messageId).then((traces) => {
      expect(traces.spans.length).to.be.at.least(3); // enqueue, process, store
    });
  });
});
```

**Workflow Integration**:
```yaml
- uses: fullstack-pw/pipelines/.github/workflows/cypress.yml@main
  with:
    env_vars: |
      {
        "CYPRESS_BASE_URL": "https://app-dev.fullstack.pw",
        "ENQUEUER_URL": "https://enqueuer-dev.fullstack.pw",
        "WRITER_URL": "https://writer-dev.fullstack.pw",
        "MEMORIZER_URL": "https://memorizer-dev.fullstack.pw",
        "ENVIRONMENT": "dev"
      }
```

### Security Testing

#### 1. Vulnerability Scanning (Trivy)

**Workflow** ([infra/.github/workflows/sec-trivy.yml](infra/.github/workflows/sec-trivy.yml)):

```yaml
name: Trivy Security Scan

on:
  pull_request:

jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

**Scans For**:
- Known CVEs in dependencies
- Misconfigurations in IaC files
- Exposed secrets in files
- Outdated base images

#### 2. Secret Scanning (TruffleHog)

**Workflow** ([infra/.github/workflows/sec-trufflehog.yml](infra/.github/workflows/sec-trufflehog.yml)):

```yaml
name: TruffleHog Secret Scan

on:
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for comprehensive scan

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified --no-update
```

**Detects**:
- AWS keys
- GitHub tokens
- Database credentials
- API keys
- Private keys
- OAuth tokens

**Prevention**: Fails PR if secrets detected

---

## Secrets Management

### SOPS with age Encryption

**Configuration** ([infra/.sops.yaml](infra/.sops.yaml)):

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea9zxpx3eagyqfqlsgdytsp
```

**Secret Structure**:
```
secrets/
├── common/
│   └── secrets.yaml       # Shared across all environments
├── dev/
│   └── secrets.yaml       # Development-specific
├── stg/
│   └── secrets.yaml       # Staging-specific
└── prod/
    └── secrets.yaml       # Production-specific
```

**Example Encrypted Secret** (secrets/common/secrets.yaml):
```yaml
vault:
  token: ENC[AES256_GCM,data:xyz123...,tag:abc...]
  addr: https://vault.fullstack.pw
harbor:
  username: admin
  password: ENC[AES256_GCM,data:def456...,tag:ghi...]
rabbitmq:
  url: ENC[AES256_GCM,data:jkl789...,tag:mno...]
sops:
  age:
    - recipient: age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea9zxpx3eagyqfqlsgdytsp
  version: 3.8.1
```

**Encryption Commands**:
```bash
# Encrypt new secret file
sops -e secrets/dev/secrets.yaml > secrets/dev/secrets.yaml.enc

# Edit encrypted file in-place
sops secrets/dev/secrets.yaml

# Decrypt for viewing
sops -d secrets/dev/secrets.yaml

# Rotate keys
sops rotate -i secrets/dev/secrets.yaml
```

**age Key Management**:
```bash
# Generate new age key pair
age-keygen -o age-key.txt

# Public key goes in .sops.yaml
# Private key stored in:
# - CI/CD: GitHub Secrets (AGE_SECRET_KEY)
# - Local: ~/.config/sops/age/keys.txt
```

### Vault Integration

**External Secrets Operator**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.fullstack.pw"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          namespace: external-secrets
          key: token
```

**External Secret Example**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: writer-secrets
  namespace: writer
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: writer-secrets
    creationPolicy: Owner
  data:
  - secretKey: rabbitmq-url
    remoteRef:
      key: writer/config
      property: rabbitmq_url
  - secretKey: database-password
    remoteRef:
      key: writer/config
      property: db_password
```

**CI/CD Secret Injection**:
```yaml
env:
  - name: RABBITMQ_URL
    valueFrom:
      secretKeyRef:
        name: writer-secrets
        key: rabbitmq-url
```

### Pipeline Secrets

**GitHub Actions Secrets**:
```yaml
env:
  HARBOR_KEY: ${{ secrets.HARBOR_KEY }}
  VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
  VAULT_ADDR: ${{ secrets.VAULT_ADDR }}
  AGE_SECRET_KEY: ${{ secrets.AGE_SECRET_KEY }}
```

**Kubeconfig Secret**:
```yaml
- name: Setup Kubernetes Context
  run: |
    mkdir -p /home/runner/.kube
    echo "${{ secrets.KUBECONFIG }}" | base64 -d > /home/runner/.kube/config
    chmod 600 /home/runner/.kube/config
```

**Best Practices**:
1. **Never commit plaintext secrets** - Always use SOPS or Vault
2. **Principle of least privilege** - Secrets scoped to specific namespaces
3. **Rotation** - Automated secret rotation via Vault
4. **Audit logging** - Track secret access in Vault
5. **Short-lived tokens** - CI/CD tokens expire after workflow completion

---

## Observability & Monitoring

### Health Checks

**Application Health Endpoints**:
```go
// /health - Readiness and liveness
func healthHandler(w http.ResponseWriter, r *http.Request) {
    health := HealthStatus{
        Status:    "healthy",
        Timestamp: time.Now().Unix(),
        Checks: map[string]string{
            "rabbitmq": checkRabbitMQ(),
            "database": checkDatabase(),
        },
    }

    if health.Checks["rabbitmq"] != "ok" || health.Checks["database"] != "ok" {
        health.Status = "unhealthy"
        w.WriteHeader(http.StatusServiceUnavailable)
    }

    json.NewEncoder(w).Encode(health)
}
```

**Kubernetes Probes**:
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

### OpenTelemetry Integration

**Collector Configuration**:
```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "opentelemetry-collector.observability.svc.cluster.local:4317"
  - name: OTEL_SERVICE_NAME
    value: "writer"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "environment=dev,version=1.0.0"
```

**Application Instrumentation** (Go):
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() {
    exporter, _ := otlptracegrpc.New(context.Background())

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("writer"),
        )),
    )

    otel.SetTracerProvider(tp)
}

// Trace HTTP requests
func tracedHandler(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        tracer := otel.Tracer("http-server")
        ctx, span := tracer.Start(r.Context(), r.URL.Path)
        defer span.End()

        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### Pipeline Observability

**Terraform Plan Visibility**:
```yaml
- name: Comment Plan on PR
  run: |
    PLAN_OUTPUT=$(terraform show -no-color tfplan)
    gh pr comment ${{ github.event.pull_request.number }} \
      --body "### Terraform Plan

      <details><summary>Show Plan</summary>

      \`\`\`
      ${PLAN_OUTPUT:0:65000}
      \`\`\`
      </details>"
```

**Deployment Tracking**:
```yaml
- name: Track Deployment
  run: |
    kubectl annotate deployment/${{ inputs.app_name }} \
      deployment.kubernetes.io/revision="$(git rev-parse --short HEAD)" \
      deployment.kubernetes.io/deployed-by="${{ github.actor }}" \
      deployment.kubernetes.io/deployed-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Rollout Status Monitoring**:
```yaml
- name: Monitor Rollout
  run: |
    kubectl rollout status deployment/${{ inputs.app_name }} \
      -n ${{ inputs.app_name }} \
      --timeout=5m

    # Get pod status
    kubectl get pods -n ${{ inputs.app_name }} -l app=${{ inputs.app_name }}

    # Check recent events
    kubectl get events -n ${{ inputs.app_name }} --sort-by='.lastTimestamp'
```

### Observability Stack

**Components** (Deployed via Terraform):
- **Grafana**: Dashboards and visualization
- **Prometheus**: Metrics collection and alerting
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing (via OpenTelemetry)
- **Minio**: Object storage backend

**Istio Telemetry**:
```yaml
# Automatic metrics for all services
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
spec:
  accessLogging:
    - providers:
      - name: envoy
  metrics:
    - providers:
      - name: prometheus
  tracing:
    - providers:
      - name: opentelemetry
```

---

## Self-Hosted Runner Infrastructure

### Custom Runner Image

**Dockerfile** ([infra/modules/apps/github-runner/Dockerfile](infra/modules/apps/github-runner/Dockerfile)):

```dockerfile
FROM ghcr.io/actions/actions-runner:latest

ENV DEBIAN_FRONTEND=noninteractive

# Kubernetes tools
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Infrastructure as Code
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt update && apt install terraform

# Secret management
RUN wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 \
    -O /usr/local/bin/sops && chmod +x /usr/local/bin/sops
RUN wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz \
    && tar -xzf age-*.tar.gz && mv age/age /usr/local/bin/

# Container tools
RUN apt-get update && apt-get install -y docker.io

# Configuration management
RUN pip3 install ansible hvac kubernetes boto3

# Shell completion
RUN kubectl completion bash > /etc/bash_completion.d/kubectl && \
    helm completion bash > /etc/bash_completion.d/helm

ENV DOCKER_BUILDKIT=1
```

**Deployed Tooling**:
- **kubectl** - Kubernetes CLI (latest stable)
- **Helm 3** - Kubernetes package manager
- **Terraform** - Infrastructure as Code (HashiCorp repo)
- **SOPS 3.8.1** - Secret encryption
- **age 1.1.1** - Modern encryption tool
- **Docker CLI** - Container operations
- **Ansible** - Configuration management
- **hvac** - HashiCorp Vault Python client
- **boto3** - AWS SDK (for S3 backend)
- **kubernetes** - Python Kubernetes client

### Runner Deployment

**Terraform Module**:
```hcl
module "github_runner" {
  source = "./modules/apps/github-runner"

  namespace = "github-runners"
  replicas  = 3

  github_token = local.secrets["github_runner_token"]

  runner_labels = [
    "self-hosted",
    "kubernetes",
    "terraform",
  ]

  resources = {
    requests = {
      cpu    = "1"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2"
      memory = "4Gi"
    }
  }
}
```

**Workflow Usage**:
```yaml
jobs:
  terraform:
    runs-on: self-hosted  # Uses custom runner
    steps:
      - name: Terraform Plan
        run: terraform plan  # terraform already installed!

      - name: Decrypt Secrets
        run: sops -d secrets.yaml  # sops already installed!
```

**Benefits**:
- **Faster workflows**: No tool installation overhead
- **Consistent environment**: Same tools across all workflows
- **Access to cluster**: kubectl configured with in-cluster credentials
- **Cost savings**: Self-hosted vs GitHub-hosted minutes

---

## Advanced CI/CD Patterns

### 1. Workflow Reusability

**Central Repository Pattern**:
```
fullstack-pw/pipelines/
└── .github/workflows/
    ├── build-and-push.yml       # Reusable
    ├── deploy-kustomize.yml     # Reusable
    ├── cypress.yml              # Reusable
    └── go-tests.yml             # Reusable
```

**Calling Reusable Workflow**:
```yaml
# In demo-apps repository
jobs:
  build:
    uses: fullstack-pw/pipelines/.github/workflows/build-and-push.yml@main
    with:
      app_name: writer
      context: ./apps/writer
      dockerfile: ./apps/writer/Dockerfile
    secrets:
      HARBOR_KEY: ${{ secrets.HARBOR_KEY }}
```

**Benefits**:
- **DRY principle**: Write once, use everywhere
- **Centralized updates**: Fix bugs in one place
- **Version control**: Pin to specific commit/tag
- **Easier testing**: Test workflows in isolation

### 2. Dynamic Workflow Generation

**App Discovery from Git Changes**:
```yaml
jobs:
  detect-apps:
    runs-on: ubuntu-latest
    outputs:
      apps: ${{ steps.find-apps.outputs.apps }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Find Changed Apps
        id: find-apps
        run: |
          CHANGED_APPS=$(git diff --name-only HEAD~1 HEAD | \
            grep '^apps/' | \
            cut -d'/' -f2 | \
            sort -u | \
            jq -R -s -c 'split("\n")[:-1]')
          echo "apps=$CHANGED_APPS" >> $GITHUB_OUTPUT

  build:
    needs: detect-apps
    strategy:
      matrix:
        app: ${{ fromJson(needs.detect-apps.outputs.apps) }}
    runs-on: self-hosted
    steps:
      - name: Build ${{ matrix.app }}
        run: docker build apps/${{ matrix.app }}
```

**Matrix Parallelization**:
```yaml
strategy:
  matrix:
    app: [ascii-frontend, enqueuer, memorizer, writer]
    environment: [dev, stg, prod]
  max-parallel: 4  # Deploy 4 at a time
```

### 3. Commit-Driven Automation

**Ansible Playbook Execution**:
```yaml
# Commit message: "feat: deploy k3s cluster [ansible k8s-dev]"

on:
  push:
    branches: [main]

jobs:
  run-ansible:
    if: contains(github.event.head_commit.message, '[ansible ')
    steps:
      - name: Extract Playbook Name
        id: playbook
        run: |
          PLAYBOOK=$(echo "${{ github.event.head_commit.message }}" | \
            grep -oP '\[ansible \K[^\]]+')
          echo "name=$PLAYBOOK" >> $GITHUB_OUTPUT

      - name: Run Playbook
        run: |
          ansible-playbook ansible/${{ steps.playbook.outputs.name }}.yml
```

**Semantic Release Triggering**:
```yaml
# Commit: "feat: add new feature" → Minor version bump
# Commit: "fix: patch bug"        → Patch version bump
# Commit: "docs: update readme"   → Patch version bump
# Commit: "ci: update workflow"   → No release
```

### 4. Infrastructure GitOps

**Terraform State in Git**:
- Workspace-based isolation (dev, stg, prod)
- Plan artifacts uploaded to GitHub
- PR comments show exact changes
- Auto-apply after merge + release

**Auto-Generated Artifacts**:
```yaml
- name: Generate Ansible Inventory
  run: |
    terraform output -json vm_ips | \
      python3 generate_inventory.py > ansible/inventory.ini

- name: Commit Back to Repo
  run: |
    git add ansible/inventory.ini
    git commit -m "chore: update inventory [skip ci]"
    git push
```

**GitOps Feedback Loop**:
```
┌─────────────────────────────────────────────┐
│  1. Developer commits IaC changes           │
└─────────────────┬───────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  2. GitHub Actions: terraform plan          │
│     → Posts plan to PR comments             │
└─────────────────┬───────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  3. Code review + approval                  │
└─────────────────┬───────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  4. Merge → Release workflow                │
│     → Creates git tag (semantic version)    │
└─────────────────┬───────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  5. Terraform apply workflow                │
│     → Uses plan from step 2                 │
│     → Updates infrastructure                │
└─────────────────┬───────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  6. Post-apply automation                   │
│     → Generate inventory                    │
│     → Run Ansible if [ansible X] in commit  │
│     → Commit inventory back to repo         │
└─────────────────────────────────────────────┘
```

### 5. Workflow Chaining

**Sequential Workflow Dependencies**:
```yaml
# Release workflow must complete before apply
on:
  workflow_run:
    workflows: ["Release"]
    types: [completed]
    branches: [main]

jobs:
  terraform-apply:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
```

**Conditional Environment Progression**:
```yaml
jobs:
  deploy-dev:
    # Always runs

  deploy-stg:
    needs: [deploy-dev, test-dev]
    if: contains(github.event.inputs.environments, 'stg')

  deploy-prod:
    needs: [deploy-stg, test-stg]
    if: |
      contains(github.event.inputs.environments, 'prod') &&
      github.event.inputs.require_approval == 'true'
    environment: production  # Manual approval gate
```

---

## Key Files Reference

### Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `.releaserc.json` | Semantic release configuration | [infra/.releaserc.json](infra/.releaserc.json) |
| `.sops.yaml` | Encryption rules and age keys | [infra/.sops.yaml](infra/.sops.yaml) |
| `Makefile` | Infrastructure automation commands | [infra/Makefile](infra/Makefile) |
| `cypress.config.js` | E2E test configuration | [demo-apps/cypress.config.js](demo-apps/cypress.config.js) |
| `backend.tf` | Terraform remote state config | [infra/clusters/backend.tf](infra/clusters/backend.tf) |
| `load_secrets.py` | SOPS secret decryption script | [infra/clusters/load_secrets.py](infra/clusters/load_secrets.py) |

### Workflow Files

#### Infrastructure Repository
| Workflow | Purpose | Path |
|----------|---------|------|
| Terraform Plan | PR validation | [.github/workflows/terraform-plan.yml](infra/.github/workflows/terraform-plan.yml) |
| Terraform Apply | Post-merge infrastructure changes | [.github/workflows/terraform-apply.yml](infra/.github/workflows/terraform-apply.yml) |
| Build & Push | Docker image builds | [.github/workflows/build.yml](infra/.github/workflows/build.yml) |
| Ansible | Configuration management | [.github/workflows/ansible.yml](infra/.github/workflows/ansible.yml) |
| Trivy Scan | Vulnerability scanning | [.github/workflows/sec-trivy.yml](infra/.github/workflows/sec-trivy.yml) |
| TruffleHog Scan | Secret detection | [.github/workflows/sec-trufflehog.yml](infra/.github/workflows/sec-trufflehog.yml) |
| Conventional Commits | Commit message validation | [.github/workflows/conventional-commits.yml](infra/.github/workflows/conventional-commits.yml) |
| Release | Semantic versioning | [.github/workflows/release.yml](infra/.github/workflows/release.yml) |

#### Demo Apps Repository
| Workflow | Purpose | Path |
|----------|---------|------|
| Manual Pipeline | Multi-environment deployment | [.github/workflows/manual-pipeline.yml](demo-apps/.github/workflows/manual-pipeline.yml) |
| Automatic Pipeline | Auto-deploy on changes | [.github/workflows/pipeline.yml](demo-apps/.github/workflows/pipeline.yml) (commented) |

#### Reusable Workflows
| Workflow | Purpose | Repository |
|----------|---------|------------|
| Build & Push | Docker build/push | fullstack-pw/pipelines |
| Deploy Kustomize | Kubernetes deployment | fullstack-pw/pipelines |
| Cypress Tests | E2E testing | fullstack-pw/pipelines |
| Go Tests | Unit testing | fullstack-pw/pipelines |

### ArgoCD Manifests

| File | Purpose | Path |
|------|---------|------|
| App-of-Apps (Dev) | Parent app for dev environment | [argocd-apps/app-of-apps/dev-apps.yaml](infra/argocd-apps/app-of-apps/dev-apps.yaml) |
| Writer App | Writer service GitOps config | [argocd-apps/app-of-apps/dev/writer.yaml](infra/argocd-apps/app-of-apps/dev/writer.yaml) |
| Sync Waves Demo | Hook and wave demonstration | [argocd-apps/sync-waves-demo.yaml](infra/argocd-apps/sync-waves-demo.yaml) |

### Kustomize Configurations

| App | Base | Dev Overlay | Stg Overlay | Prod Overlay |
|-----|------|-------------|-------------|--------------|
| Writer | [base/](demo-apps/apps/writer/kustomize/base/) | [dev/](demo-apps/apps/writer/kustomize/overlays/dev/) | [stg/](demo-apps/apps/writer/kustomize/overlays/stg/) | [prod/](demo-apps/apps/writer/kustomize/overlays/prod/) |
| Enqueuer | [base/](demo-apps/apps/enqueuer/kustomize/base/) | [dev/](demo-apps/apps/enqueuer/kustomize/overlays/dev/) | [stg/](demo-apps/apps/enqueuer/kustomize/overlays/stg/) | [prod/](demo-apps/apps/enqueuer/kustomize/overlays/prod/) |
| Memorizer | [base/](demo-apps/apps/memorizer/kustomize/base/) | [dev/](demo-apps/apps/memorizer/kustomize/overlays/dev/) | [stg/](demo-apps/apps/memorizer/kustomize/overlays/stg/) | [prod/](demo-apps/apps/memorizer/kustomize/overlays/prod/) |
| CKS Frontend | [base/](https://github.com/fullstack-pw/cks-frontend/tree/main/kustomize/base) | [dev/](https://github.com/fullstack-pw/cks-frontend/tree/main/kustomize/overlays/dev) | [stg/](https://github.com/fullstack-pw/cks-frontend/tree/main/kustomize/overlays/stg) | [prod/](https://github.com/fullstack-pw/cks-frontend/tree/main/kustomize/overlays/prod) |
| CKS Backend | [base/](https://github.com/fullstack-pw/cks-backend/tree/main/kustomize/base) | [dev/](https://github.com/fullstack-pw/cks-backend/tree/main/kustomize/overlays/dev) | [stg/](https://github.com/fullstack-pw/cks-backend/tree/main/kustomize/overlays/stg) | [prod/](https://github.com/fullstack-pw/cks-backend/tree/main/kustomize/overlays/prod) |

### Container Images

| Component | Dockerfile | Purpose |
|-----------|------------|---------|
| Writer | [apps/writer/Dockerfile](demo-apps/apps/writer/Dockerfile) | Go microservice |
| Enqueuer | [apps/enqueuer/Dockerfile](demo-apps/apps/enqueuer/Dockerfile) | Go with Chromium |
| CKS Frontend | [Dockerfile](https://github.com/fullstack-pw/cks-frontend/blob/main/Dockerfile) | Next.js web interface |
| CKS Backend | [Dockerfile](https://github.com/fullstack-pw/cks-backend/blob/main/Dockerfile) | Go API with KubeVirt |
| GitHub Runner | [modules/apps/github-runner/Dockerfile](infra/modules/apps/github-runner/Dockerfile) | Self-hosted runner |

---

## Summary

This homelab infrastructure demonstrates **production-grade CI/CD practices** including:

### Core Strengths
1. **Full GitOps**: ArgoCD app-of-apps pattern with automated sync
2. **Multi-Environment Pipeline**: Progressive delivery through dev → stg → prod
3. **Security First**: SOPS encryption, secret scanning, vulnerability scanning
4. **Quality Gates**: Conventional commits, automated testing, health checks
5. **Infrastructure as Code**: Terraform with workspace isolation and GitOps
6. **Container Best Practices**: Multi-stage builds, immutable tags, minimal images
7. **Automation**: Commit-driven Ansible, semantic releases, inventory updates
8. **Observability**: OpenTelemetry, health checks, deployment tracking
9. **Self-Service**: Manual workflows with environment selection
10. **Reusability**: Central workflow library, Terraform modules

### Maturity Indicators
- **Automated releases**: Semantic versioning with conventional commits
- **Test automation**: Unit tests, E2E tests, security scans on every PR
- **Self-healing**: ArgoCD auto-sync and rollback
- **Progressive delivery**: Environment gates with automated testing
- **Secret management**: SOPS + Vault integration
- **Infrastructure GitOps**: Terraform plans in PRs, auto-apply on merge
- **Observability**: Full tracing, metrics, and logging stack

This CI/CD setup is suitable for production workloads and showcases modern DevOps/Platform Engineering best practices.

---

**Created**: 2025-11-04
**Repository**: [fullstack-pw](https://github.com/fullstack-pw/)
**Author**: Pedro (Homelab Infrastructure)
