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
    apiVersion = "cluster.x-k8s.io/v1beta1"
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
        kind       = "KubeadmControlPlane"
        apiVersion = "controlplane.cluster.x-k8s.io/v1beta1"
        name       = "${each.value.name}-control-plane"
      }
      infrastructureRef = {
        kind       = "ProxmoxCluster"
        apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
        name       = each.value.name
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
    apiVersion = "controlplane.cluster.x-k8s.io/v1beta1"
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
            extraArgs = {
              "enable-hostpath-provisioner" = "true"
            }
          }
        }
        preKubeadmCommands = [
          "/etc/kube-vip-prepare.sh"
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
                creationTimestamp = null
                name              = "kube-vip"
                namespace         = "kube-system"
              }
              spec = {
                containers = [
                  {
                    name  = "kube-vip"
                    image = "ghcr.io/kube-vip/kube-vip:v1.0.2"
                    args  = ["manager"]
                    env = [
                      {
                        name  = "cp_enable"
                        value = "true"
                      },
                      {
                        name  = "cp_namespace"
                        value = "kube-system"
                      },

                      {
                        name  = "vip_interface"
                        value = ""
                      },
                      {
                        name  = "vip_arp"
                        value = "true"
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
                        name  = "vip_leaderelection"
                        value = "true"
                      },
                      {
                        name  = "vip_leasename"
                        value = "plndr-cp-lock"
                      },
                      {
                        name  = "vip_leaseduration"
                        value = "5"
                      },
                      {
                        name  = "vip_renewdeadline"
                        value = "3"
                      },
                      {
                        name  = "vip_retryperiod"
                        value = "1"
                      },
                      {
                        name  = "vip_cidr"
                        value = "32"
                      },
                    ]
                    imagePullPolicy = "IfNotPresent"
                    resources       = {}
                    securityContext = {
                      capabilities = {
                        add = ["NET_ADMIN", "NET_RAW", "SYS_TIME"]
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
                hostAliases = [
                  {
                    ip        = "127.0.0.1"
                    hostnames = ["localhost", "kubernetes"]
                  }
                ]
                hostNetwork = true
                volumes = [
                  {
                    name = "kubeconfig"
                    hostPath = {
                      path = "/etc/kubernetes/admin.conf"
                      type = "FileOrCreate"
                    }
                  }
                ]
              }
              status = {}
            })
          },
          {
            path        = "/etc/kube-vip-prepare.sh"
            owner       = "root:root"
            permissions = "0700"
            content     = <<-EOF
              #!/bin/bash

              # Redirect all output to log file
              exec > /var/log/kube-vip-prepare.log 2>&1

              set -ex
              echo "=== kube-vip-prepare.sh starting at $(date) ==="
              IS_KUBEADM_INIT="false"

              # cloud-init kubeadm init
              echo "Checking for /run/kubeadm/kubeadm.yaml..."
              if [[ -f /run/kubeadm/kubeadm.yaml ]]; then
                echo "Found /run/kubeadm/kubeadm.yaml - this is kubeadm init"
                IS_KUBEADM_INIT="true"
              else
                echo "/run/kubeadm/kubeadm.yaml not found"
              fi

              # ignition kubeadm init
              echo "Checking for /etc/kubeadm.sh with 'kubeadm init'..."
              if [[ -f /etc/kubeadm.sh ]] && grep -q -e "kubeadm init" /etc/kubeadm.sh; then
                echo "Found /etc/kubeadm.sh with 'kubeadm init' - this is kubeadm init"
                IS_KUBEADM_INIT="true"
              else
                echo "/etc/kubeadm.sh check did not match"
              fi

              echo "IS_KUBEADM_INIT=$IS_KUBEADM_INIT"

              if [[ "$IS_KUBEADM_INIT" == "true" ]]; then
                echo "This is kubeadm init - patching kube-vip.yaml hostPath to use super-admin.conf"
                echo "Before patch:"
                grep -n "path.*admin.conf" /etc/kubernetes/manifests/kube-vip.yaml || echo "No admin.conf path references found"

                # Only change the hostPath, NOT the mountPath inside the container
                # The container expects the file at /etc/kubernetes/admin.conf
                # But we mount super-admin.conf from the host to that location
                sed -i 's#"path": "/etc/kubernetes/admin.conf"#"path": "/etc/kubernetes/super-admin.conf"#g' \
                  /etc/kubernetes/manifests/kube-vip.yaml

                echo "After patch:"
                grep -n "path.*admin.conf\|path.*super-admin.conf" /etc/kubernetes/manifests/kube-vip.yaml || echo "No conf path references found"
                echo "Patch completed successfully"
              else
                echo "This is NOT kubeadm init - leaving kube-vip.yaml unchanged"
              fi

              echo "=== kube-vip-prepare.sh completed at $(date) ==="
            EOF
          }
        ]
        initConfiguration = {
          nodeRegistration = {
            criSocket = "unix:///var/run/containerd/containerd.sock"
            kubeletExtraArgs = {
              "provider-id" = "proxmox://'{{ ds.meta_data.instance_id }}'"
            }
          }
        }
        joinConfiguration = {
          nodeRegistration = {
            criSocket = "unix:///var/run/containerd/containerd.sock"
            kubeletExtraArgs = {
              "provider-id" = "proxmox://'{{ ds.meta_data.instance_id }}'"
            }
          }
        }
        postKubeadmCommands = [
          "kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f ${each.value.cni_manifest_url}"
        ]
      }
      machineTemplate = {
        infrastructureRef = {
          kind       = "ProxmoxMachineTemplate"
          apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
          name       = "${each.value.name}-control-plane-template"
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
          metadataSettings = {
            providerIDInjection = each.value.provider_id_injection
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
    apiVersion = "cluster.x-k8s.io/v1beta1"
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
              kind       = "KubeadmConfigTemplate"
              apiVersion = "bootstrap.cluster.x-k8s.io/v1beta1"
              name       = "${each.value.name}-worker-config"
            }
          }
          infrastructureRef = {
            kind       = "ProxmoxMachineTemplate"
            apiVersion = "infrastructure.cluster.x-k8s.io/v1alpha1"
            name       = "${each.value.name}-worker-template"
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
    apiVersion = "bootstrap.cluster.x-k8s.io/v1beta1"
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
              kubeletExtraArgs = {
                "provider-id" = "proxmox://'{{ ds.meta_data.instance_id }}'"
              }
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
          metadataSettings = {
            providerIDInjection = each.value.provider_id_injection
          }
        }
      }
    }
  }

  depends_on = [module.namespace]
}
