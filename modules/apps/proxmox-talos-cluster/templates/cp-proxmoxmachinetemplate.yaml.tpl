apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${control_plane_template_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      disks:
        bootVolume:
          disk: scsi0
          sizeGb: ${cp_disk_size}
      format: ${disk_format}
      full: true
      memoryMiB: ${cp_memory}
      vmIDRange:
        start: 351
        end: 400
      network:
        default:
          bridge: ${network_bridge}
          model: ${network_model}
      numCores: ${cp_cores}
      numSockets: ${cp_sockets}
      sourceNode: ${source_node}
      templateID: ${template_id}
      checks:
        skipCloudInitStatus: ${skip_cloud_init_status}
        skipQemuGuestAgent: ${skip_qemu_guest_agent}
      metadataSettings:
        providerIDInjection: ${provider_id_injection}
