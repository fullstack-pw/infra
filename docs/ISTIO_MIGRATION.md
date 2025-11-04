# Istio Migration Guide

## Overview

This document describes the migration from Traefik (K3s default ingress) to Istio service mesh on the dev/stg/prod clusters.

**Status**: POC implemented on dev cluster
**Date**: 2025-11-03

## Architecture

### Components

1. **Istio Control Plane (istiod)**: Manages configuration and certificate distribution
2. **Istio Ingress Gateway**: Entry point for external traffic (replaces Traefik)
3. **Gateway Resources**: Define listeners and TLS configuration
4. **VirtualService Resources**: Define routing rules to backend services

### Infrastructure Layout

```
External Traffic
      ↓
Istio Ingress Gateway (LoadBalancer via K3s ServiceLB/Klipper-LB)
      ↓
Gateway Resource (defines listeners)
      ↓
VirtualService (defines routing rules)
      ↓
Kubernetes Service
      ↓
Application Pods
```

## Implementation

### Modules Created

#### 1. Istio Base Module (`modules/apps/istio/`)

Installs Istio using official Helm charts in the recommended order:
- **`istio-base`**: CRDs and cluster-scoped resources (installed first)
- **`istiod`**: Control plane (depends on istio-base)
- **`istio-ingressgateway`**: Ingress gateway (depends on istiod)

**CRD Installation**:
The `istio-base` Helm chart automatically installs all Istio CRDs including:
- `Gateway` (networking.istio.io/v1beta1)
- `VirtualService` (networking.istio.io/v1beta1)
- `DestinationRule` (networking.istio.io/v1beta1)
- `ServiceEntry` (networking.istio.io/v1beta1)
- `AuthorizationPolicy` (security.istio.io/v1beta1)
- And 30+ other Istio CRDs

No manual CRD installation required - Helm manages the full lifecycle.

**Terraform CRD Handling**:
All `kubernetes_manifest` resources that use Istio CRDs include `computed_fields = ["spec"]` to prevent Terraform from validating the manifest during the plan phase. This avoids the chicken-and-egg problem where Terraform tries to validate Gateway/VirtualService resources before the CRDs are installed. The CRDs are installed by the `istio-base` Helm chart, and `depends_on` ensures proper ordering.

**Configuration**:
- Gateway service type: **LoadBalancer** (K3s has built-in ServiceLB/Klipper-LB)
- LoadBalancer IP: Auto-assigned by K3s ServiceLB
- Telemetry: Enabled with stdout access logs
- Tracing: Disabled (can be enabled later for Jaeger integration)

#### 2. Istio Gateway Base Module (`modules/base/istio-gateway/`)

Reusable Terraform module for creating Istio Gateway resources.

**Features**:
- HTTP/HTTPS server configuration
- Automatic HTTPS redirect
- TLS configuration (SIMPLE, PASSTHROUGH, MUTUAL)
- Support for custom servers (e.g., TCP for databases)
- External-DNS annotations

#### 3. Istio VirtualService Base Module (`modules/base/istio-virtualservice/`)

Reusable Terraform module for creating Istio VirtualService resources.

**Features**:
- HTTP/HTTPS routing with path matching
- Multiple routes and destinations
- Timeouts and retry policies
- Header manipulation
- URI rewriting
- CORS policies
- Traffic mirroring and fault injection

### External-DNS Integration

Updated [modules/apps/externaldns/main.tf](../modules/apps/externaldns/main.tf) to support Istio:

**Changes**:
1. Added RBAC permissions for `networking.istio.io` API group (Gateway, VirtualService)
2. Added RBAC permissions for `gateway.networking.k8s.io` API group (future)
3. Updated cloudflare external-dns to include `--source=istio-gateway`

**Configuration**:
```hcl
container_args = [
  "--source=ingress",
  "--source=istio-gateway",  # NEW
  "--registry=txt",
  "--txt-owner-id=k8s-${terraform.workspace}",
  "--policy=sync",
  "--provider=cloudflare",
]
```

### PostgreSQL with TLS Passthrough

PostgreSQL requires special handling due to SSL passthrough.

**Challenge**: PostgreSQL handles TLS termination internally, so Istio must pass through encrypted traffic.

**Solution**:
1. Gateway configured with TLS mode `PASSTHROUGH` on port 5432
2. VirtualService uses TCP routing instead of HTTP
3. SNI (Server Name Indication) matching on hostname

**Implementation** ([modules/apps/postgres/main.tf](../modules/apps/postgres/main.tf)):
```hcl
# Gateway with TLS passthrough
module "istio_gateway" {
  enabled   = var.use_istio
  name      = "${var.release_name}-postgresql-gateway"
  namespace = "istio-system"
  hosts     = [var.ingress_host]

  additional_servers = [
    {
      port = {
        number   = 5432
        name     = "tcp-postgres"
        protocol = "TLS"
      }
      hosts = [var.ingress_host]
      tls = {
        mode = "PASSTHROUGH"
      }
    }
  ]
}

# VirtualService with TCP routing
resource "kubernetes_manifest" "istio_virtualservice" {
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    spec = {
      tls = [
        {
          match = [
            {
              port     = 5432
              sniHosts = [var.ingress_host]
            }
          ]
          route = [
            {
              destination = {
                host = "${var.release_name}-postgresql.${namespace}.svc.cluster.local"
                port = { number = 5432 }
              }
            }
          ]
        }
      ]
    }
  }
}
```

### Cert-Manager Integration

Cert-manager works with Istio Gateway resources for TLS certificate management.

**How it works**:
1. Gateway resource specifies `credentialName` for TLS secret
2. Cert-manager watches for Gateway annotations: `cert-manager.io/cluster-issuer`
3. Cert-manager creates Certificate resource and provisions TLS secret
4. Istio Gateway uses the secret for TLS termination

**Note**: For TLS PASSTHROUGH mode (PostgreSQL), cert-manager is not needed as the application handles TLS.

## Deployment

### Prerequisites

1. K3s cluster running
2. Traefik disabled (you handle this)
3. Terraform workspace selected: `terraform workspace select dev`
4. Vault token exported: `export VAULT_TOKEN=<token>`

### Steps

1. **Initialize Terraform**:
   ```bash
   cd clusters
   terraform init
   ```

2. **First Apply - Deploy Istio and CRDs**:
   ```bash
   terraform plan
   terraform apply
   ```

   **Important**: On the first deployment, `create_default_gateway` and `use_istio` are set to `false` to avoid the CRD validation issue during plan phase. This first apply will:
   - Create istio-system namespace
   - Deploy istio-base (installs all CRDs)
   - Deploy istiod (control plane)
   - Deploy istio-ingressgateway
   - Update external-dns permissions and configuration

3. **Enable Istio Resources**:
   After the first apply succeeds, edit `clusters/modules.tf`:

   ```hcl
   # In module "istio" block:
   create_default_gateway = true  # Change from false to true

   # In module "testing_postgres" block:
   use_istio = true  # Change from false to true
   ```

4. **Second Apply - Create Gateway and VirtualService**:
   ```bash
   terraform plan  # Should now succeed - CRDs are installed
   terraform apply
   ```

   This second apply will:
   - Create default Gateway in istio-system
   - Create PostgreSQL-specific Gateway
   - Create PostgreSQL VirtualService
   - Enable Istio ingress for dev-postgres

5. **Verify Istio installation**:
   ```bash
   kubectl get pods -n istio-system
   ```

   Expected output:
   ```
   NAME                                    READY   STATUS    RESTARTS   AGE
   istiod-<hash>                           1/1     Running   0          2m
   istio-ingressgateway-<hash>             1/1     Running   0          1m
   ```

6. **Verify Gateway** (after second apply):
   ```bash
   kubectl get gateway -n istio-system
   ```

   Expected output:
   ```
   NAME                            AGE
   default-gateway                 1m
   testing-postgresql-gateway      1m
   ```

7. **Verify VirtualService** (after second apply):
   ```bash
   kubectl get virtualservice -n default
   ```

   Expected output:
   ```
   NAME                       GATEWAYS                                        HOSTS                        AGE
   testing-postgresql-vs      ["istio-system/testing-postgresql-gateway"]    ["dev.postgres.fullstack.pw"]   1m
   ```

8. **Check Istio Ingress Gateway Service**:
   ```bash
   kubectl get svc -n istio-system istio-ingressgateway
   ```

   Expected output (LoadBalancer via K3s ServiceLB):
   ```
   NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
   istio-ingressgateway   LoadBalancer   10.43.xxx.xxx   192.168.x.xxx    80:xxxxx/TCP,443:xxxxx/TCP   2m
   ```

   The EXTERNAL-IP should be assigned automatically by K3s ServiceLB (Klipper-LB).

9. **Verify DNS record creation** (after second apply):
   ```bash
   kubectl logs -n external-dns deployment/external-dns-cloudflare | grep dev.postgres
   ```

   Look for: `CREATE: dev.postgres.fullstack.pw`

10. **Test PostgreSQL connectivity** (after second apply):
   ```bash
   psql "postgresql://appuser:<password>@dev.postgres.fullstack.pw:5432/postgres?sslmode=require"
   ```

## Traefik Removal

After verifying Istio is working:

1. **Disable Traefik in K3s**:
   - Edit K3s config: `/etc/rancher/k3s/config.yaml`
   - Add: `disable: traefik`
   - Restart K3s: `systemctl restart k3s`

2. **Remove Traefik resources** (if any exist):
   ```bash
   kubectl delete ingressroute --all -A
   kubectl delete middleware --all -A
   kubectl delete tlsoption --all -A
   ```

## Monitoring

### Istio Metrics

Istio exports Prometheus metrics on port 15020:

```bash
kubectl port-forward -n istio-system deployment/istio-ingressgateway 15020:15020
curl http://localhost:15020/stats/prometheus
```

Key metrics:
- `istio_requests_total`: Total requests through gateway
- `istio_request_duration_milliseconds`: Request latency
- `istio_request_bytes`: Request size
- `istio_response_bytes`: Response size

### Access Logs

Istio logs to stdout (configured in istiod-values.yaml):

```bash
kubectl logs -n istio-system deployment/istio-ingressgateway -f
```

Log format: JSON with fields:
- `authority`: Host header
- `bytes_received`/`bytes_sent`: Traffic size
- `duration`: Request duration
- `method`: HTTP method
- `path`: Request path
- `protocol`: HTTP version
- `response_code`: HTTP status code
- `upstream_cluster`: Backend service

### Integration with Observability Stack

To enable distributed tracing to Jaeger:

1. Update Istio module in `clusters/modules.tf`:
   ```hcl
   module "istio" {
     enable_tracing   = true
     tracing_endpoint = "otel-collector.observability-box.svc.cluster.local:9411"
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

## Troubleshooting

### Gateway not receiving traffic

**Check LoadBalancer service**:
```bash
kubectl get svc -n istio-system istio-ingressgateway
```

Verify:
- TYPE is `LoadBalancer`
- EXTERNAL-IP is assigned (not `<pending>`)
- K3s ServiceLB has allocated an IP from your network range

**If EXTERNAL-IP is pending**, check K3s ServiceLB status:
```bash
kubectl get pods -n kube-system -l app=svclb-istio-ingressgateway
```

**Check Gateway status**:
```bash
kubectl describe gateway -n istio-system default-gateway
```

### VirtualService not routing

**Check Gateway attachment**:
```bash
kubectl get virtualservice testing-postgresql-vs -n default -o yaml
```

Verify `gateways` field matches Gateway namespace/name.

**Check service exists**:
```bash
kubectl get svc testing-postgresql -n default
```

### DNS records not created

**Check external-dns logs**:
```bash
kubectl logs -n external-dns deployment/external-dns-cloudflare
```

Look for errors or permissions issues.

**Verify Gateway has annotation**:
```bash
kubectl get gateway testing-postgresql-gateway -n istio-system -o yaml | grep external-dns
```

### PostgreSQL connection fails

**Check TLS passthrough**:
```bash
kubectl get gateway testing-postgresql-gateway -n istio-system -o yaml
```

Verify server has `tls.mode: PASSTHROUGH`.

**Check VirtualService TCP routing**:
```bash
kubectl get virtualservice testing-postgresql-vs -n default -o yaml
```

Verify it uses `tls` field (not `http`) for routing.

**Test with openssl**:
```bash
openssl s_client -connect dev.postgres.fullstack.pw:5432 -servername dev.postgres.fullstack.pw
```

Should show PostgreSQL SSL certificate.

### Istio pods not starting

**Check CRDs installed**:
```bash
kubectl get crd | grep istio
```

**Check Helm releases**:
```bash
helm list -n istio-system
```

Expected: `istio-base`, `istiod`, `istio-ingressgateway`

**Check resource limits**:
```bash
kubectl describe pod -n istio-system <pod-name>
```

Look for OOMKilled or resource constraints.

## Migration to Other Clusters

After successful POC on dev cluster:

1. **Update workload list** in `clusters/variables.tf`:
   ```hcl
   stg = [
     "externaldns",
     "cert_manager",
     "external_secrets",
     "istio",  # ADD THIS
   ]
   ```

2. **Disable Traefik** on target cluster

3. **Apply Terraform**:
   ```bash
   terraform workspace select stg
   terraform apply
   ```

4. **Update applications** to use `use_istio = true`

## Migrating Other Applications

### HTTP/HTTPS Applications

For standard web applications, use the base Istio modules:

```hcl
# Gateway
module "app_gateway" {
  source = "../../base/istio-gateway"

  name      = "my-app-gateway"
  namespace = "istio-system"
  hosts     = ["app.fullstack.pw"]

  http_enabled   = true
  https_enabled  = true
  https_redirect = true
  tls_mode       = "SIMPLE"
}

# VirtualService
module "app_virtualservice" {
  source = "../../base/istio-virtualservice"

  name      = "my-app-vs"
  namespace = "default"
  hosts     = ["app.fullstack.pw"]
  gateways  = ["istio-system/my-app-gateway"]

  service_name = "my-app"
  service_port = 80
  path         = "/"
}
```

### Applications with SSL Passthrough

For applications like PostgreSQL, Redis with TLS, or custom TCP services:

1. Use `additional_servers` in Gateway with `tls.mode = "PASSTHROUGH"`
2. Use VirtualService with `tls` routing (not `http`)
3. Match on SNI hostname and port

See PostgreSQL implementation in [modules/apps/postgres/main.tf](../modules/apps/postgres/main.tf:161-235).

### Applications with Custom Annotations

Map Traefik/NGINX annotations to Istio equivalents:

| Traefik/NGINX | Istio Equivalent |
|---------------|------------------|
| `traefik.ingress.kubernetes.io/router.entrypoints: websecure` | Gateway HTTPS server |
| `nginx.ingress.kubernetes.io/ssl-redirect: "true"` | Gateway `httpsRedirect: true` |
| `nginx.ingress.kubernetes.io/proxy-body-size: 0` | VirtualService timeout (no direct equivalent) |
| `nginx.ingress.kubernetes.io/backend-protocol: HTTPS` | DestinationRule with TLS (not implemented yet) |
| `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` | Gateway TLS PASSTHROUGH mode |
| `nginx.ingress.kubernetes.io/auth-*` | Requires Istio AuthorizationPolicy |
| `nginx.ingress.kubernetes.io/rate-limit` | Requires Istio rate limiting (EnvoyFilter) |

## Best Practices

1. **Use a single Gateway per namespace**: Share Gateway across multiple VirtualServices
2. **Enable telemetry**: Essential for debugging and monitoring
3. **Use cert-manager for TLS**: Automate certificate lifecycle
4. **Test with openssl**: Verify TLS configuration before application testing
5. **Monitor access logs**: Enable JSON logging for structured log parsing
6. **Use DestinationRules for mTLS**: When enabling service mesh features
7. **Gradual rollout**: Test on dev → stg → prod

## Known Limitations

1. **No direct replacement for NGINX proxy-body-size**: Use VirtualService timeouts instead
2. **No built-in rate limiting UI**: Requires EnvoyFilter CRDs
3. **No built-in auth**: Requires AuthorizationPolicy or external auth service
4. **Cert-manager Gateway API support**: Requires cert-manager 1.13+
5. **External-DNS istio-gateway source**: Requires external-dns 0.13+

## Next Steps

### Phase 1: Validation (Current)
- ✅ Istio installed on dev cluster
- ✅ PostgreSQL migrated with TLS passthrough
- ✅ External-DNS configured for Istio Gateway
- ⏳ Test PostgreSQL connectivity
- ⏳ Monitor metrics and logs

### Phase 2: Additional Features
- Enable distributed tracing to Jaeger
- Add ServiceMonitor for Prometheus scraping
- Configure Grafana dashboards for Istio metrics
- Implement AuthorizationPolicies for security

### Phase 3: Expansion
- Migrate stg cluster
- Migrate prod cluster
- Enable sidecar injection for service mesh features
- Implement traffic management (canary, blue-green)

## References

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Gateway API](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [Istio VirtualService API](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [External-DNS Istio Source](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/sources/istio.md)
- [Cert-Manager with Istio](https://cert-manager.io/docs/usage/istio/)

## Support

For issues or questions:
1. Check Istio logs: `kubectl logs -n istio-system deployment/istiod`
2. Check Gateway status: `kubectl describe gateway -n istio-system <gateway-name>`
3. Check VirtualService status: `kubectl describe virtualservice <vs-name>`
4. Review Terraform plan before applying changes
5. Test connectivity with `curl -v` or `openssl s_client`
