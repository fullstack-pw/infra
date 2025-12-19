apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${worker_template_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      disks:
        bootVolume:
          disk: scsi0
          sizeGb: ${wk_disk_size}
      format: ${disk_format}
      full: true
      memoryMiB: ${wk_memory}
      vmIDRange:
        start: 301
        end: 350
      network:
        default:
          bridge: ${network_bridge}
          model: ${network_model}
      numCores: ${wk_cores}
      numSockets: ${wk_sockets}
      sourceNode: ${source_node}
      templateID: ${template_id}
      checks:
        skipCloudInitStatus: ${skip_cloud_init_status}
        skipQemuGuestAgent: ${skip_qemu_guest_agent}
      metadataSettings:
        providerIDInjection: ${provider_id_injection}
