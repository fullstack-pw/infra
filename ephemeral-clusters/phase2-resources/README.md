# Phase 2: CRD-Dependent Resources

This directory contains templates for resources that depend on CRDs installed in Phase 1.

## Resources

1. **ClusterIssuer** (cert-manager) - Let's Encrypt issuer for TLS certificates
2. **DNSEndpoint** (external-dns) - DNS record for `pr-<pr>-<repo>.ephemeral.fullstack.pw`
3. **ExternalSecret** (external-secrets) - Sync secrets from Vault (if needed)
4. **PostgreSQL Cluster** (CloudNativePG) - Single-instance PostgreSQL database for applications

## Installation

These resources can only be installed AFTER Phase 1 CRDs are established.

```bash
# Render templates with environment variables
export DNS_NAME=pr-42-cksbackend.ephemeral.fullstack.pw
export CLUSTER_IP=192.168.1.140
export CLUSTER_NAME=pr-cksbackend-42
export PR_NUMBER=42

envsubst < *.yaml.tpl | kubectl apply -f - --kubeconfig <ephemeral-cluster-kubeconfig>
```

## Files

- `clusterissuer.yaml` - Static Let's Encrypt configuration
- `dnsendpoint.yaml.tpl` - Template for DNS record creation
- `externalsecret.yaml.tpl` - Template for Vault secret sync (optional)
- `postgres-cluster.yaml.tpl` - Template for PostgreSQL single-instance cluster

## DNS Strategy

The DNSEndpoint resource directly creates DNS records in Cloudflare/Pi-hole without waiting for Ingress.
This ensures DNS is ready before application deployment.

Alternative: Let external-dns watch Ingress resources and create DNS automatically.
