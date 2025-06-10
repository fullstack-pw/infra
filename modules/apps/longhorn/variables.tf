variable "namespace" {
  description = "Kubernetes namespace for Longhorn"
  type        = string
  default     = "longhorn-system"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = "1.9.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 600
}

variable "replica_count" {
  description = "Default number of replicas for Longhorn volumes"
  type        = number
  default     = 1
}

variable "default_data_path" {
  description = "Default path for Longhorn data"
  type        = string
  default     = "/var/lib/longhorn"
}

variable "guaranteed_engine_manager_cpu" {
  description = "Guaranteed CPU allocation for engine manager"
  type        = string
  default     = "200m"
}

variable "guaranteed_replica_manager_cpu" {
  description = "Guaranteed CPU allocation for replica manager"
  type        = string
  default     = "200m"
}

variable "create_default_disk_labeled_nodes" {
  description = "Create default disk on labeled nodes"
  type        = bool
  default     = true
}

variable "ingress_enabled" {
  description = "Enable ingress for Longhorn UI"
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Hostname for Longhorn UI ingress"
  type        = string
  default     = "longhorn.fullstack.pw"
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for Longhorn ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for Longhorn ingress"
  type        = string
  default     = "longhorn-tls"
}

variable "ingress_annotations" {
  description = "Additional annotations for Longhorn ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "longhorn.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
}

variable "cert_manager_cluster_issuer" {
  description = "Name of the cert-manager ClusterIssuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "enable_psp" {
  description = "Enable Pod Security Policy"
  type        = bool
  default     = false
}

variable "image_pull_policy" {
  description = "Image pull policy for Longhorn components"
  type        = string
  default     = "IfNotPresent"
}

variable "service_account" {
  description = "Service account name for Longhorn"
  type        = string
  default     = "longhorn-service-account"
}

variable "default_settings" {
  description = "Default Longhorn settings"
  type        = map(any)
  default = {
    # # -- Setting that allows Longhorn to automatically attach a volume and create snapshots or backups when recurring jobs are run.
    # allowRecurringJobWhileVolumeDetached = true
    # # -- Setting that allows Longhorn to automatically create a default disk only on nodes with the label "node.longhorn.io/create-default-disk=true" (if no other disks exist). When this setting is disabled, Longhorn creates a default disk on each node that is added to the cluster.
    # createDefaultDiskLabeledNodes = false
    # # -- Default path for storing data on a host. The default value is "/var/lib/longhorn/".
    # defaultDataPath = "/var/lib/longhorn/"
    # # -- Default data locality. A Longhorn volume has data locality if a local replica of the volume exists on the same node as the pod that is using the volume.
    # defaultDataLocality = null
    # # -- Setting that allows scheduling on nodes with healthy replicas of the same volume. This setting is disabled by default.
    # replicaSoftAntiAffinity = null
    # # -- Setting that automatically rebalances replicas when an available node is discovered.
    # replicaAutoBalance = null
    # # -- Percentage of storage that can be allocated relative to hard drive capacity. The default value is "100".
    # storageOverProvisioningPercentage = null
    # # -- Percentage of minimum available disk capacity. When the minimum available capacity exceeds the total available capacity, the disk becomes unschedulable until more space is made available for use. The default value is "25".
    # storageMinimalAvailablePercentage = null
    # # -- Percentage of disk space that is not allocated to the default disk on each new Longhorn node.
    # storageReservedPercentageForDefaultDisk = null
    # # -- Upgrade Checker that periodically checks for new Longhorn versions. When a new version is available, a notification appears on the Longhorn UI. This setting is enabled by default
    # upgradeChecker = null
    # # -- The Upgrade Responder sends a notification whenever a new Longhorn version that you can upgrade to becomes available. The default value is https =//longhorn-upgrade-responder.rancher.io/v1/checkupgrade.
    # upgradeResponderURL = null
    # # -- Default number of replicas for volumes created using the Longhorn UI. For Kubernetes configuration, modify the `numberOfReplicas` field in the StorageClass. The default value is "3".
    # defaultReplicaCount = null
    # # -- Default name of Longhorn static StorageClass. "storageClassName" is assigned to PVs and PVCs that are created for an existing Longhorn volume. "storageClassName" can also be used as a label, so it is possible to use a Longhorn StorageClass to bind a workload to an existing PV without creating a Kubernetes StorageClass object. "storageClassName" needs to be an existing StorageClass. The default value is "longhorn-static".
    # defaultLonghornStaticStorageClass = null
    # # -- Number of minutes that Longhorn keeps a failed backup resource. When the value is "0", automatic deletion is disabled.
    # failedBackupTTL = null
    # # -- Number of minutes that Longhorn allows for the backup execution. The default value is "1".
    # backupExecutionTimeout = null
    # # -- Setting that restores recurring jobs from a backup volume on a backup target and creates recurring jobs if none exist during backup restoration.
    # restoreVolumeRecurringJobs = null
    # # -- Maximum number of successful recurring backup and snapshot jobs to be retained. When the value is "0", a history of successful recurring jobs is not retained.
    # recurringSuccessfulJobsHistoryLimit = null
    # # -- Maximum number of failed recurring backup and snapshot jobs to be retained. When the value is "0", a history of failed recurring jobs is not retained.
    # recurringFailedJobsHistoryLimit = null
    # # -- Maximum number of snapshots or backups to be retained.
    # recurringJobMaxRetention = null
    # # -- Maximum number of failed support bundles that can exist in the cluster. When the value is "0", Longhorn automatically purges all failed support bundles.
    # supportBundleFailedHistoryLimit = null
    # # -- Taint or toleration for system-managed Longhorn components.
    # # Specify values using a semicolon-separated list in `kubectl taint` syntax (Example = key1=value1 =effect; key2=value2 =effect).
    # taintToleration = null
    # # -- Node selector for system-managed Longhorn components.
    # systemManagedComponentsNodeSelector = null
    # # -- PriorityClass for system-managed Longhorn components.
    # # This setting can help prevent Longhorn components from being evicted under Node Pressure.
    # # Notice that this will be applied to Longhorn user-deployed components by default if there are no priority class values set yet, such as `longhornManager.priorityClass`.
    # priorityClass = &defaultPriorityClassNameRef "longhorn-critical"
    # # -- Setting that allows Longhorn to automatically salvage volumes when all replicas become faulty (for example, when the network connection is interrupted). Longhorn determines which replicas are usable and then uses these replicas for the volume. This setting is enabled by default.
    # autoSalvage = null
    # # -- Setting that allows Longhorn to automatically delete a workload pod that is managed by a controller (for example, daemonset) whenever a Longhorn volume is detached unexpectedly (for example, during Kubernetes upgrades). After deletion, the controller restarts the pod and then Kubernetes handles volume reattachment and remounting.
    # autoDeletePodWhenVolumeDetachedUnexpectedly = null
    # # -- Setting that prevents Longhorn Manager from scheduling replicas on a cordoned Kubernetes node. This setting is enabled by default.
    # disableSchedulingOnCordonedNode = null
    # # -- Setting that allows Longhorn to schedule new replicas of a volume to nodes in the same zone as existing healthy replicas. Nodes that do not belong to any zone are treated as existing in the zone that contains healthy replicas. When identifying zones, Longhorn relies on the label "topology.kubernetes.io/zone=<Zone name of the node>" in the Kubernetes node object.
    # replicaZoneSoftAntiAffinity = null
    # # -- Setting that allows scheduling on disks with existing healthy replicas of the same volume. This setting is enabled by default.
    # replicaDiskSoftAntiAffinity = null
    # # -- Policy that defines the action Longhorn takes when a volume is stuck with a StatefulSet or Deployment pod on a node that failed.
    # nodeDownPodDeletionPolicy = null
    # # -- Policy that defines the action Longhorn takes when a node with the last healthy replica of a volume is drained.
    # nodeDrainPolicy = null
    # # -- Setting that allows automatic detaching of manually-attached volumes when a node is cordoned.
    # detachManuallyAttachedVolumesWhenCordoned = null
    # # -- Number of seconds that Longhorn waits before reusing existing data on a failed replica instead of creating a new replica of a degraded volume.
    # replicaReplenishmentWaitInterval = null
    # # -- Maximum number of replicas that can be concurrently rebuilt on each node.
    # concurrentReplicaRebuildPerNodeLimit = null
    # # -- Maximum number of volumes that can be concurrently restored on each node using a backup. When the value is "0", restoration of volumes using a backup is disabled.
    # concurrentVolumeBackupRestorePerNodeLimit = null
    # # -- Setting that disables the revision counter and thereby prevents Longhorn from tracking all write operations to a volume. When salvaging a volume, Longhorn uses properties of the "volume-head-xxx.img" file (the last file size and the last time the file was modified) to select the replica to be used for volume recovery. This setting applies only to volumes created using the Longhorn UI.
    # disableRevisionCounter = "true"
    # # -- Image pull policy for system-managed pods, such as Instance Manager, engine images, and CSI Driver. Changes to the image pull policy are applied only after the system-managed pods restart.
    # systemManagedPodsImagePullPolicy = null
    # # -- Setting that allows you to create and attach a volume without having all replicas scheduled at the time of creation.
    # allowVolumeCreationWithDegradedAvailability = null
    # # -- Setting that allows Longhorn to automatically clean up the system-generated snapshot after replica rebuilding is completed.
    # autoCleanupSystemGeneratedSnapshot = null
    # # -- Setting that allows Longhorn to automatically clean up the snapshot generated by a recurring backup job.
    # autoCleanupRecurringJobBackupSnapshot = null
    # # -- Maximum number of engines that are allowed to concurrently upgrade on each node after Longhorn Manager is upgraded. When the value is "0", Longhorn does not automatically upgrade volume engines to the new default engine image version.
    # concurrentAutomaticEngineUpgradePerNodeLimit = null
    # # -- Number of minutes that Longhorn waits before cleaning up the backing image file when no replicas in the disk are using it.
    # backingImageCleanupWaitInterval = null
    # # -- Number of seconds that Longhorn waits before downloading a backing image file again when the status of all image disk files changes to "failed" or "unknown".
    # backingImageRecoveryWaitInterval = null
    # # -- Percentage of the total allocatable CPU resources on each node to be reserved for each instance manager pod when the V1 Data Engine is enabled. The default value is "12".
    # guaranteedInstanceManagerCPU = null
    # # -- Setting that notifies Longhorn that the cluster is using the Kubernetes Cluster Autoscaler.
    # kubernetesClusterAutoscalerEnabled = null
    # # -- Enables Longhorn to automatically delete orphaned resources and their associated data or processes (e.g., stale replicas). Orphaned resources on failed or unknown nodes are not automatically cleaned up. 
    # # You need to specify the resource types to be deleted using a semicolon-separated list (e.g., `replica-data;instance`). Available items are = `replica-data`, `instance`.
    # orphanResourceAutoDeletion = null
    # # -- Specifies the wait time, in seconds, before Longhorn automatically deletes an orphaned Custom Resource (CR) and its associated resources.
    # # Note that if a user manually deletes an orphaned CR, the deletion occurs immediately and does not respect this grace period.
    # orphanResourceAutoDeletionGracePeriod = null
    # # -- Storage network for in-cluster traffic. When unspecified, Longhorn uses the Kubernetes cluster network.
    # storageNetwork = null
    # # -- Flag that prevents accidental uninstallation of Longhorn.
    # deletingConfirmationFlag = null
    # # -- Timeout between the Longhorn Engine and replicas. Specify a value between "8" and "30" seconds. The default value is "8".
    # engineReplicaTimeout = null
    # # -- Setting that allows you to enable and disable snapshot hashing and data integrity checks.
    # snapshotDataIntegrity = null
    # # -- Setting that allows disabling of snapshot hashing after snapshot creation to minimize impact on system performance.
    # snapshotDataIntegrityImmediateCheckAfterSnapshotCreation = null
    # # -- Setting that defines when Longhorn checks the integrity of data in snapshot disk files. You must use the Unix cron expression format.
    # snapshotDataIntegrityCronjob = null
    # # -- Setting that allows Longhorn to automatically mark the latest snapshot and its parent files as removed during a filesystem trim. Longhorn does not remove snapshots containing multiple child files.
    # removeSnapshotsDuringFilesystemTrim = null
    # # -- Setting that allows fast rebuilding of replicas using the checksum of snapshot disk files. Before enabling this setting, you must set the snapshot-data-integrity value to "enable" or "fast-check".
    # fastReplicaRebuildEnabled = null
    # # -- Number of seconds that an HTTP client waits for a response from a File Sync server before considering the connection to have failed.
    # replicaFileSyncHttpClientTimeout = null
    # # -- Number of seconds that Longhorn allows for the completion of replica rebuilding and snapshot cloning operations.
    # longGRPCTimeOut = null
    # # -- Log levels that indicate the type and severity of logs in Longhorn Manager. The default value is "Info". (Options = "Panic", "Fatal", "Error", "Warn", "Info", "Debug", "Trace")
    # logLevel = null
    # # -- Setting that allows you to specify a backup compression method.
    # backupCompressionMethod = null
    # # -- Maximum number of worker threads that can concurrently run for each backup.
    # backupConcurrentLimit = null
    # # -- Maximum number of worker threads that can concurrently run for each restore operation.
    # restoreConcurrentLimit = null
    # # -- Setting that allows you to enable the V1 Data Engine.
    # v1DataEngine = null
    # # -- Setting that allows you to enable the V2 Data Engine, which is based on the Storage Performance Development Kit (SPDK). The V2 Data Engine is an experimental feature and should not be used in production environments.
    # v2DataEngine = null
    # # -- Setting that allows you to configure maximum huge page size (in MiB) for the V2 Data Engine.
    # v2DataEngineHugepageLimit = null
    # # -- Number of millicpus on each node to be reserved for each Instance Manager pod when the V2 Data Engine is enabled. The default value is "1250".
    # v2DataEngineGuaranteedInstanceManagerCPU = null
    # # -- CPU cores on which the Storage Performance Development Kit (SPDK) target daemon should run. The SPDK target daemon is located in each Instance Manager pod. Ensure that the number of cores is less than or equal to the guaranteed Instance Manager CPUs for the V2 Data Engine. The default value is "0x1".
    # v2DataEngineCPUMask = null
    # # -- Setting that allows scheduling of empty node selector volumes to any node.
    # allowEmptyNodeSelectorVolume = null
    # # -- Setting that allows scheduling of empty disk selector volumes to any disk.
    # allowEmptyDiskSelectorVolume = null
    # # -- Setting that allows Longhorn to periodically collect anonymous usage data for product improvement purposes. Longhorn sends collected data to the [Upgrade Responder](https =//github.com/longhorn/upgrade-responder) server, which is the data source of the Longhorn Public Metrics Dashboard (https =//metrics.longhorn.io). The Upgrade Responder server does not store data that can be used to identify clients, including IP addresses.
    # allowCollectingLonghornUsageMetrics = null
    # # -- Setting that temporarily prevents all attempts to purge volume snapshots.
    # disableSnapshotPurge = null
    # # -- Maximum snapshot count for a volume. The value should be between 2 to 250
    # snapshotMaxCount = null
    # # -- Setting that allows you to configure the log level of the SPDK target daemon (spdk_tgt) of the V2 Data Engine.
    # v2DataEngineLogLevel = null
    # # -- Setting that allows you to configure the log flags of the SPDK target daemon (spdk_tgt) of the V2 Data Engine.
    # v2DataEngineLogFlags = null
    # # -- Setting allows you to enable or disable snapshot hashing and data integrity checking for the V2 Data Engine.
    # v2DataEngineSnapshotDataIntegrity = null
    # # -- Setting that freezes the filesystem on the root partition before a snapshot is created.
    # freezeFilesystemForSnapshot = null
    # # -- Setting that automatically cleans up the snapshot when the backup is deleted.
    # autoCleanupSnapshotWhenDeleteBackup = null
    # # -- Setting that automatically cleans up the snapshot after the on-demand backup is completed.
    # autoCleanupSnapshotAfterOnDemandBackupCompleted = null
    # # -- Setting that allows Longhorn to detect node failure and immediately migrate affected RWX volumes.
    # rwxVolumeFastFailover = null
    # # -- Enables automatic rebuilding of degraded replicas while the volume is detached. This setting only takes effect if the individual volume setting is set to `ignored` or `enabled`.
    # offlineRelicaRebuilding = null
    # # -- Setting that allows you to update the default backupstore.

  }
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
