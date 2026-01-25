# Kubernetes Cluster Module

Clean, refactored module for provisioning Kubernetes clusters on Proxmox via Cluster API.

## Architecture

This module uses a **facade pattern** with type-specific submodules:

- `kubernetes-cluster` - Main facade (routing layer)
- `kubernetes-cluster-core` - Shared infrastructure (namespaces, credentials, templates)
- `kubernetes-cluster-talos` - Talos Linux clusters
- `kubernetes-cluster-kubeadm` - Vanilla Kubernetes (kubeadm)
- `kubernetes-cluster-k3s` - K3s clusters
- `kubernetes-cluster-k0s` - K0s clusters (k0smotron)
- `kubernetes-cluster-rke2` - RKE2 clusters

## Supported Cluster Types

| Type | Default Version | Status |
|------|----------------|--------|
| talos | v1.33.0 | ✅ Implemented |
| kubeadm | v1.31.4 | 🚧 Planned |
| k3s | v1.30.6+k3s1 | 🚧 Planned |
| k0s | v1.31.x | 🚧 Planned |
| rke2 | v1.33.1+rke2r1 | 🚧 Planned |

## Usage

```hcl
module "kubernetes_clusters" {
  source = "../modules/apps/kubernetes-cluster"

  clusters = [
    {
      cluster_type              = "talos"  # or kubeadm, k3s, k0s, rke2
      name                      = "dev"
      kubernetes_version        = "v1.33.0"
      control_plane_endpoint_ip = "192.168.1.50"
      ip_range_start            = "192.168.1.51"
      ip_range_end              = "192.168.1.56"
      gateway                   = "192.168.1.1"
      prefix                    = 24
      dns_servers               = ["192.168.1.3", "8.8.4.4"]

      source_node   = "node03"
      template_id   = 9005
      allowed_nodes = ["node03"]

      cp_replicas = 1
      wk_replicas = 2

      cp_disk_size = 20
      cp_memory    = 4096
      cp_cores     = 4
      wk_disk_size = 30
      wk_memory    = 8192
      wk_cores     = 8
    }
  ]

  cluster_api_dependencies = [module.clusterapi_operator]

  create_proxmox_secret = true
  proxmox_url           = "https://proxmox.example.com"
  proxmox_secret        = var.proxmox_secret
  proxmox_token         = var.proxmox_token
}
```

## Migration from proxmox-cluster

This module replaces `modules/apps/proxmox-cluster` with a cleaner architecture.

**Interface compatibility**: The `clusters` variable structure is identical, making migration straightforward.

**State migration** (non-destructive):
```bash
cd clusters
tofu state mv 'module.proxmox_clusters[0]' 'module.kubernetes_clusters[0]'
# See migration guide for full commands
```

## Requirements

- OpenTofu/Terraform >= 1.9.0
- Cluster API operator deployed on management cluster (tools)
- Proxmox credentials

## Outputs

- `all_clusters` - All clusters created across all types
- `talos_clusters`, `kubeadm_clusters`, etc. - Type-specific outputs
- `core_namespaces` - Created namespaces

## Development

To add a new cluster type:

1. Create `kubernetes-cluster-<type>/` module
2. Add type-specific templates
3. Update facade `main.tf` to include new module
4. Test independently
5. No changes to existing modules required!
