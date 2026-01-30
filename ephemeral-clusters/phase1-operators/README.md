# Phase 1: CRD Operators

This directory contains manifests for operators that provide CRDs needed by Phase 2 resources.

## Operators

1. **cert-manager v1.16.2** - For TLS certificate management
   - Installed via official manifest from GitHub releases
   - Provides CRDs: Certificate, ClusterIssuer, Issuer, CertificateRequest

2. **external-dns v0.14.1** - For automatic DNS record creation (Cloudflare)
   - Custom manifest with Cloudflare provider configuration
   - Domain filter: ephemeral.fullstack.pw
   - Sources: ingress, crd (DNSEndpoint)

3. **external-secrets v0.12.1** - For syncing secrets from Vault
   - Minimal deployment with basic CRDs
   - Provides CRDs: SecretStore, ExternalSecret

4. **CloudNativePG v1.28.0** - PostgreSQL operator for database management
   - Provides CRDs: Cluster, Backup, ScheduledBackup, Pooler
   - Supports single-instance PostgreSQL databases for ephemeral environments

## Installation

```bash
# Apply all operators via kustomize
kubectl apply -k ephemeral-clusters/phase1-operators/ --kubeconfig <ephemeral-kubeconfig>

# Wait for deployments ready
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=3m --kubeconfig <ephemeral-kubeconfig>
kubectl wait --for=condition=Available deployment/external-dns-cloudflare -n external-dns --timeout=3m --kubeconfig <ephemeral-kubeconfig>
kubectl wait --for=condition=Available deployment/external-secrets -n external-secrets --timeout=3m --kubeconfig <ephemeral-kubeconfig>
kubectl wait --for=condition=Available deployment/cnpg-controller-manager -n cnpg-system --timeout=3m --kubeconfig <ephemeral-kubeconfig>

# Wait for CRDs established
kubectl wait --for condition=established --timeout=3m --kubeconfig <ephemeral-kubeconfig> \
  crd/certificates.cert-manager.io \
  crd/clusterissuers.cert-manager.io \
  crd/dnsendpoints.externaldns.k8s.io \
  crd/secretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io \
  crd/clusters.postgresql.cnpg.io \
  crd/backups.postgresql.cnpg.io
```

## Required Secrets

External-DNS requires a Cloudflare API token secret:

```bash
# Create cloudflare-api-token secret
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=<CLOUDFLARE_API_TOKEN> \
  -n external-dns \
  --kubeconfig <ephemeral-kubeconfig>
```

This secret will be created automatically during cluster provisioning from Vault.

## Notes

- These operators must be installed and their CRDs must be established before Phase 2 resources can be applied
- Installation takes ~2-3 minutes total
- All operators run with minimal resource requests for ephemeral clusters
