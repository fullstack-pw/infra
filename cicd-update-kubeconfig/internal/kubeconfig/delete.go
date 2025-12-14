package kubeconfig

import (
	"fmt"
)

// Delete removes a cluster from the kubeconfig
// Returns the updated kubeconfig as YAML string
// If the cluster is not found, returns the original config (idempotent)
func Delete(existing, clusterName string) (string, error) {
	// If no existing config, nothing to delete (idempotent)
	if existing == "" {
		return "", nil
	}

	// Parse existing config
	config, err := parseKubeconfig(existing)
	if err != nil {
		return "", fmt.Errorf("parse existing kubeconfig: %w", err)
	}

	// Track if we found the cluster
	foundCluster := false

	// Remove entries for this cluster
	originalClusterCount := len(config.Clusters)
	config.Clusters = filterClusters(config.Clusters, clusterName)
	if len(config.Clusters) < originalClusterCount {
		foundCluster = true
	}

	originalContextCount := len(config.Contexts)
	config.Contexts = filterContexts(config.Contexts, clusterName)
	if len(config.Contexts) < originalContextCount {
		foundCluster = true
	}

	originalUserCount := len(config.Users)
	config.Users = filterUsers(config.Users, clusterName)
	if len(config.Users) < originalUserCount {
		foundCluster = true
	}

	// If cluster wasn't found, return original (idempotent)
	if !foundCluster {
		return existing, nil
	}

	// Handle current-context cleanup
	if config.CurrentContext == clusterName {
		if len(config.Clusters) > 0 {
			// Set to first available cluster
			config.CurrentContext = config.Clusters[0].Name
		} else {
			// No clusters left, clear current-context
			config.CurrentContext = ""
		}
	}

	return serializeKubeconfig(config)
}
