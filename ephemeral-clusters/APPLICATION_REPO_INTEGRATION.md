# Application Repository Integration Guide

This guide explains how to integrate ephemeral cluster provisioning into your application repositories (cks-backend, cks-frontend, demo-apps).

## Overview

When a PR is opened in your application repository, the workflow will:
1. Trigger ephemeral cluster creation in the infra repo
2. Wait for cluster to be ready
3. Build and deploy your application to the ephemeral cluster
4. Run tests against the ephemeral environment
5. Post results as PR comments
6. Clean up when PR is closed

**Optional PostgreSQL Support**: Set `install_postgres: "true"` in the client-payload to install CloudNativePG operator and create a PostgreSQL cluster. This is useful for applications that need a database (e.g., writer-app). For applications that don't need PostgreSQL (e.g., cks-backend, cks-frontend), keep it as `"false"`.

## Required Setup

### 1. GitHub Personal Access Token (PAT)

Create a PAT with the following permissions:
- `repo` (Full control of private repositories)
- `workflow` (Update GitHub Action workflows)

Store it as a repository secret named `PAT_TOKEN` in both:
- Your application repository
- The infra repository

### 2. Add PR Workflow to Application Repo

Create `.github/workflows/pr-ephemeral.yml` in your application repository:

```yaml
name: PR Ephemeral Environment

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

env:
  REGISTRY: harbor.fullstack.pw
  IMAGE_NAME: ${{ github.repository }}

jobs:
  create-environment:
    if: github.event.action != 'closed'
    runs-on: self-hosted
    outputs:
      cluster_name: ${{ steps.cluster-info.outputs.cluster_name }}
      dns_name: ${{ steps.cluster-info.outputs.dns_name }}
    steps:
      - name: Set cluster info
        id: cluster-info
        run: |
          CLUSTER_NAME="pr-${{ github.event.repository.name }}-${{ github.event.pull_request.number }}"
          DNS_NAME="pr-${{ github.event.pull_request.number }}-${{ github.event.repository.name }}.ephemeral.fullstack.pw"
          echo "cluster_name=$CLUSTER_NAME" >> $GITHUB_OUTPUT
          echo "dns_name=$DNS_NAME" >> $GITHUB_OUTPUT

      - name: Trigger ephemeral cluster creation
        if: github.event.action == 'opened' || github.event.action == 'reopened'
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.PAT_TOKEN }}
          repository: fullstack-pw/infra
          event-type: create_ephemeral_cluster
          client-payload: |
            {
              "pr_number": "${{ github.event.pull_request.number }}",
              "repository": "${{ github.event.repository.name }}",
              "branch": "${{ github.head_ref }}",
              "install_postgres": "false"
            }

      - name: Wait for cluster ready
        if: github.event.action == 'opened' || github.event.action == 'reopened'
        run: |
          echo "Waiting for ephemeral cluster to be ready..."
          CLUSTER_NAME="${{ steps.cluster-info.outputs.cluster_name }}"

          # Wait up to 15 minutes for cluster provisioning
          timeout 900 bash -c '
            until kubectl get cluster '"$CLUSTER_NAME"' -n '"$CLUSTER_NAME"' --context tools -o jsonpath="{.status.conditions[?(@.type==\"Available\")].status}" | grep -q "True"; do
              echo "Cluster not ready yet, waiting..."
              sleep 30
            done
          ' || echo "Timeout waiting for cluster - will continue anyway"

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:pr-${{ github.event.pull_request.number }} .

      - name: Push to Harbor
        run: |
          echo ${{ secrets.HARBOR_PASSWORD }} | docker login ${{ env.REGISTRY }} -u ${{ secrets.HARBOR_USERNAME }} --password-stdin
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:pr-${{ github.event.pull_request.number }}

      - name: Deploy to ephemeral cluster
        run: |
          # Get kubeconfig from Vault
          export VAULT_ADDR=https://vault.fullstack.pw
          export VAULT_TOKEN=${{ secrets.VAULT_TOKEN }}
          vault kv get -field=value kv/ephemeral-clusters/${{ steps.cluster-info.outputs.cluster_name }}/kubeconfig > /tmp/kubeconfig

          # Deploy using kubectl or ArgoCD
          kubectl apply -k kustomize/overlays/ephemeral --kubeconfig /tmp/kubeconfig

          # Wait for deployment
          kubectl rollout status deployment/${{ github.event.repository.name }} \
            -n default --timeout=5m --kubeconfig /tmp/kubeconfig

      - name: Run tests
        run: |
          # Run your test suite against the ephemeral environment
          # Example: Cypress tests
          npx cypress run --config baseUrl=https://${{ steps.cluster-info.outputs.dns_name }}

      - name: Post test results
        if: always()
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const testStatus = '${{ job.status }}' === 'success' ? '✅ Passed' : '❌ Failed';
            const dnsName = '${{ steps.cluster-info.outputs.dns_name }}';

            const body = `## Test Results

**Environment:** https://${dnsName}
**Status:** ${testStatus}

You can access your application at: https://${dnsName}

The environment will remain available for manual testing until the PR is closed.`;

            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });

  cleanup:
    if: github.event.action == 'closed'
    runs-on: self-hosted
    steps:
      - name: Wait 1 hour grace period
        run: |
          echo "Waiting 1 hour before cleanup..."
          sleep 3600

      - name: Trigger cluster deletion
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.PAT_TOKEN }}
          repository: fullstack-pw/infra
          event-type: delete_ephemeral_cluster
          client-payload: |
            {
              "cluster_name": "pr-${{ github.event.repository.name }}-${{ github.event.pull_request.number }}",
              "pr_number": "${{ github.event.pull_request.number }}",
              "repository": "${{ github.event.repository.name }}"
            }
```

### 3. Create Kustomize Ephemeral Overlay

Create `kustomize/overlays/ephemeral/kustomization.yaml` in your application repository:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - ../../base

patches:
  - path: deployment-patch.yaml
  - path: ingress-patch.yaml

images:
  - name: IMAGE_NAME
    newName: harbor.fullstack.pw/your-repo/your-app
    newTag: pr-123  # Will be replaced by workflow

replicas:
  - name: your-app
    count: 1  # Single replica for ephemeral
```

Create `kustomize/overlays/ephemeral/deployment-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: your-app
        env:
        - name: ENVIRONMENT
          value: "ephemeral"
        - name: LOG_LEVEL
          value: "debug"
```

Create `kustomize/overlays/ephemeral/ingress-patch.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: your-app
  annotations:
    kubernetes.io/ingress.class: "traefik"
    external-dns.alpha.kubernetes.io/hostname: "pr-123-your-repo.ephemeral.fullstack.pw"
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  rules:
  - host: pr-123-your-repo.ephemeral.fullstack.pw
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: your-app
            port:
              number: 80
  tls:
  - hosts:
    - pr-123-your-repo.ephemeral.fullstack.pw
    secretName: your-app-tls
```

## DNS Naming Convention

Ephemeral clusters use the following DNS pattern:

```
pr-<PR_NUMBER>-<REPOSITORY>.ephemeral.fullstack.pw
```

Examples:
- `pr-42-cksbackend.ephemeral.fullstack.pw`
- `pr-123-demoapps.ephemeral.fullstack.pw`
- `pr-5-cksfrontend.ephemeral.fullstack.pw`

## Resource Limits

- **Max concurrent clusters**: 10 (limited by IP pool 192.168.1.140-149)
- **Max cluster lifetime**: 3 days (auto-cleanup)
- **Grace period after PR close**: 1 hour
- **Cluster resources**: 4 CPU, 8GB RAM, 20GB disk per cluster

## Troubleshooting

### Cluster provisioning fails

Check the infra repo workflow logs:
- Go to https://github.com/fullstack-pw/infra/actions
- Find the "Ephemeral Cluster Management" workflow run
- Check for errors in the logs

### DNS not resolving

Wait a few minutes for DNS propagation. You can check with:

```bash
dig +short pr-<number>-<repo>.ephemeral.fullstack.pw
```

### Application won't deploy

1. Check kubeconfig is in Vault:
   ```bash
   vault kv get kv/ephemeral-clusters/pr-<repo>-<number>/kubeconfig
   ```

2. Check operators are running:
   ```bash
   kubectl get pods -A --kubeconfig /tmp/kubeconfig
   ```

3. Check Phase 2 resources:
   ```bash
   kubectl get clusterissuer,dnsendpoint --kubeconfig /tmp/kubeconfig
   ```

## Testing Locally

You can test the ephemeral cluster provisioning manually:

```bash
# From infra repo
cd /home/pedro/repos/infra

# Run provisioning test
./ephemeral-clusters/test-provisioning.sh pr-test-local 999 your-repo

# Cleanup
./ephemeral-clusters/test-cleanup.sh pr-test-local
```

## Next Steps

1. Add this workflow to your application repository
2. Create the kustomize ephemeral overlay
3. Test by opening a PR
4. Monitor the ephemeral cluster creation in the infra repo actions
5. Access your application at the ephemeral DNS name
6. Run tests and verify everything works
7. Close the PR and verify cleanup after 1 hour

## Support

- **Infra repo**: https://github.com/fullstack-pw/infra
- **Ephemeral cluster plan**: /home/pedro/.claude/plans/zippy-noodling-bumblebee.md
- **IP pool manager**: `./clusters/scripts/ip_pool_manager.sh list`
