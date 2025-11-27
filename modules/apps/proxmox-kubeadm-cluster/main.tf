locals {
  # Flatten the clusters configuration for for_each
  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }
}

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

# Create Proxmox credentials secret
resource "kubernetes_secret" "proxmox_credentials" {
  count = var.create_proxmox_secret ? 1 : 0

  metadata {
    name      = var.credentials_ref_name
    namespace = var.namespace
  }

  data = {
    url    = var.proxmox_url
    secret = var.proxmox_secret
    token  = var.proxmox_token
  }

  type = "Opaque"

  depends_on = [module.namespace]
}

# Cluster resource
resource "kubernetes_manifest" "cluster" {
  for_each = local.clusters

  manifest = {
    apiVersion = "cluster.x-k8s.io/v1beta2"
    kind       = "Cluster"
    metadata = {
      name      = each.value.name
      namespace = var.namespace
    }
    spec = {
      clusterNetwork = {
        pods = {
          cidrBlocks = [each.value.pod_cidr]
        }
        services = {
          cidrBlocks = [each.value.service_cidr]
        }
      }
      controlPlaneRef = {
        apiGroup = "controlplane.cluster.x-k8s.io"
        kind     = "KubeadmControlPlane"
        name     = "${each.value.name}-control-plane"
      }
      infrastructureRef = {
        apiGroup = "infrastructure.cluster.x-k8s.io"
        kind     = "ProxmoxCluster"
        name     = each.value.name
      }
    }
  }

  depends_on = [module.namespace]
}

# ProxmoxCluster resource
resource "kubernetes_manifest" "proxmox_cluster" {
  for_each = local.clusters

  manifest = {
    apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
    kind       = "ProxmoxCluster"
    metadata = {
      name      = each.value.name
      namespace = var.namespace
    }
    spec = {
      controlPlaneEndpoint = {
        host = each.value.control_plane_endpoint_ip
        port = each.value.control_plane_endpoint_port
      }
      ipv4Config = {
        addresses = ["${each.value.ip_range_start}-${each.value.ip_range_end}"]
        gateway   = each.value.gateway
        prefix    = each.value.prefix
      }
      dnsServers   = each.value.dns_servers
      allowedNodes = length(each.value.allowed_nodes) > 0 ? each.value.allowed_nodes : null
      credentialsRef = {
        name = var.credentials_ref_name
      }
    }
  }

  depends_on = [module.namespace]
}

# KubeadmControlPlane resource
resource "kubernetes_manifest" "kubeadm_control_plane" {
  for_each = local.clusters

  manifest = {
    apiVersion = "controlplane.cluster.x-k8s.io/v1beta2"
    kind       = "KubeadmControlPlane"
    metadata = {
      name      = "${each.value.name}-control-plane"
      namespace = var.namespace
    }
    spec = {
      version  = each.value.kubernetes_version
      replicas = each.value.cp_replicas
      kubeadmConfigSpec = {
        users = [
          {
            name              = "ubuntu"
            sshAuthorizedKeys = var.ssh_authorized_keys
            sudo              = "ALL=(ALL) NOPASSWD:ALL"
          }
        ]
        clusterConfiguration = {
          apiServer = {
            certSANs = [
              each.value.control_plane_endpoint_ip,
              "localhost",
              "127.0.0.1"
            ]
          }
          controllerManager = {
            extraArgs = [
              {
                name  = "enable-hostpath-provisioner"
                value = "true"
              }
            ]
          }
        }
        preKubeadmCommands = [
          "ip addr add ${each.value.control_plane_endpoint_ip}/24 dev ens18"
        ]
        files = [
          {
            path        = "/etc/kubernetes/manifests/kube-vip.yaml"
            owner       = "root:root"
            permissions = "0644"
            content = yamlencode({
              apiVersion = "v1"
              kind       = "Pod"
              metadata = {
                name      = "kube-vip"
                namespace = "kube-system"
              }
              spec = {
                containers = [
                  {
                    name  = "kube-vip"
                    image = "ghcr.io/kube-vip/kube-vip:v0.8.10"
                    args  = ["manager"]
                    env = [
                      {
                        name  = "cp_enable"
                        value = "true"
                      },
                      {
                        name  = "vip_interface"
                        value = "ens18"
                      },
                      {
                        name  = "address"
                        value = each.value.control_plane_endpoint_ip
                      },
                      {
                        name  = "port"
                        value = "6443"
                      },
                      {
                        name  = "vip_arp"
                        value = "true"
                      },
                      {
                        name  = "vip_leaderelection"
                        value = "false"
                      },
                      {
                        name  = "vip_startleader"
                        value = "true"
                      },
                      {
                        name  = "vip_leaseduration"
                        value = "15"
                      },
                      {
                        name  = "vip_renewdeadline"
                        value = "10"
                      },
                      {
                        name  = "vip_retryperiod"
                        value = "2"
                      }
                    ]
                    securityContext = {
                      capabilities = {
                        add = ["NET_ADMIN", "NET_RAW"]
                      }
                    }
                    volumeMounts = [
                      {
                        mountPath = "/etc/kubernetes/admin.conf"
                        name      = "kubeconfig"
                      }
                    ]
                  }
                ]
                hostNetwork = true
                volumes = [
                  {
                    name = "kubeconfig"
                    hostPath = {
                      path = "/etc/kubernetes/admin.conf"
                    }
                  }
                ]
              }
            })
          }
        ]
        initConfiguration = {
          nodeRegistration = {
            criSocket = "unix:///var/run/containerd/containerd.sock"
            kubeletExtraArgs = [
              {
                name  = "cloud-provider"
                value = "external"
              }
            ]
          }
        }
        joinConfiguration = {
          nodeRegistration = {
            criSocket = "unix:///var/run/containerd/containerd.sock"
            kubeletExtraArgs = [
              {
                name  = "cloud-provider"
                value = "external"
              }
            ]
          }
        }
        postKubeadmCommands = [
          "kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f ${each.value.cni_manifest_url}"
        ]
      }
      machineTemplate = {
        spec = {
          infrastructureRef = {
            apiGroup = "infrastructure.cluster.x-k8s.io"
            kind     = "ProxmoxMachineTemplate"
            name     = "${each.value.name}-control-plane-template"
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}

# ProxmoxMachineTemplate for control plane
resource "kubernetes_manifest" "control_plane_machine_template" {
  for_each = local.clusters

  manifest = {
    apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
    kind       = "ProxmoxMachineTemplate"
    metadata = {
      name      = "${each.value.name}-control-plane-template"
      namespace = var.namespace
    }
    spec = {
      template = {
        spec = {
          sourceNode = each.value.source_node
          templateID = each.value.template_id
          format     = each.value.disk_format
          full       = true
          numCores   = each.value.cp_cores
          numSockets = each.value.cp_sockets
          memoryMiB  = each.value.cp_memory
          disks = {
            bootVolume = {
              disk   = "scsi0"
              sizeGb = each.value.cp_disk_size
            }
          }
          network = {
            default = {
              bridge = each.value.network_bridge
              model  = each.value.network_model
            }
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}

# MachineDeployment for workers
resource "kubernetes_manifest" "machine_deployment" {
  for_each = local.clusters

  manifest = {
    apiVersion = "cluster.x-k8s.io/v1beta2"
    kind       = "MachineDeployment"
    metadata = {
      name      = "${each.value.name}-workers"
      namespace = var.namespace
    }
    spec = {
      clusterName = each.value.name
      replicas    = each.value.wk_replicas
      selector = {
        matchLabels = {
          "cluster.x-k8s.io/cluster-name" = each.value.name
        }
      }
      template = {
        metadata = {
          labels = {
            "cluster.x-k8s.io/cluster-name" = each.value.name
          }
        }
        spec = {
          clusterName = each.value.name
          version     = each.value.kubernetes_version
          bootstrap = {
            configRef = {
              apiGroup = "bootstrap.cluster.x-k8s.io"
              kind     = "KubeadmConfigTemplate"
              name     = "${each.value.name}-worker-config"
            }
          }
          infrastructureRef = {
            apiGroup = "infrastructure.cluster.x-k8s.io"
            kind     = "ProxmoxMachineTemplate"
            name     = "${each.value.name}-worker-template"
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}

# KubeadmConfigTemplate for workers
resource "kubernetes_manifest" "kubeadm_config_template" {
  for_each = local.clusters

  manifest = {
    apiVersion = "bootstrap.cluster.x-k8s.io/v1beta2"
    kind       = "KubeadmConfigTemplate"
    metadata = {
      name      = "${each.value.name}-worker-config"
      namespace = var.namespace
    }
    spec = {
      template = {
        spec = {
          users = [
            {
              name              = "ubuntu"
              sshAuthorizedKeys = var.ssh_authorized_keys
              sudo              = "ALL=(ALL) NOPASSWD:ALL"
            }
          ]
          joinConfiguration = {
            nodeRegistration = {
              criSocket = "unix:///var/run/containerd/containerd.sock"
              kubeletExtraArgs = [
                {
                  name  = "cloud-provider"
                  value = "external"
                }
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}

# ProxmoxMachineTemplate for workers
resource "kubernetes_manifest" "worker_machine_template" {
  for_each = local.clusters

  manifest = {
    apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
    kind       = "ProxmoxMachineTemplate"
    metadata = {
      name      = "${each.value.name}-worker-template"
      namespace = var.namespace
    }
    spec = {
      template = {
        spec = {
          sourceNode = each.value.source_node
          templateID = each.value.template_id
          format     = each.value.disk_format
          full       = true
          numCores   = each.value.wk_cores
          numSockets = each.value.wk_sockets
          memoryMiB  = each.value.wk_memory
          disks = {
            bootVolume = {
              disk   = "scsi0"
              sizeGb = each.value.wk_disk_size
            }
          }
          network = {
            default = {
              bridge = each.value.network_bridge
              model  = each.value.network_model
            }
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}
