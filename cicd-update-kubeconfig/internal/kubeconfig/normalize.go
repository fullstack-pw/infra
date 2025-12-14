package kubeconfig

// NormalizeNames updates all names in the kubeconfig to use the cluster name consistently
func NormalizeNames(config *Config, clusterName string) {
	// Update all cluster entries to use cluster name
	for i := range config.Clusters {
		config.Clusters[i].Name = clusterName
	}

	// Update all user entries to use cluster name
	for i := range config.Users {
		config.Users[i].Name = clusterName
	}

	// Update all context entries
	for i := range config.Contexts {
		config.Contexts[i].Name = clusterName
		config.Contexts[i].Context.Cluster = clusterName
		config.Contexts[i].Context.User = clusterName
	}

	// Update current-context
	config.CurrentContext = clusterName
}
