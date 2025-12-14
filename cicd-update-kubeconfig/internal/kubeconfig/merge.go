package kubeconfig

import (
	"bytes"
	"fmt"

	"gopkg.in/yaml.v3"
)

// Merge merges a new cluster kubeconfig into an existing merged kubeconfig
// Returns the merged kubeconfig as YAML string
func Merge(existing, new, clusterName string) (string, error) {
	// If no existing config, just normalize and return the new one
	if existing == "" {
		newConfig, err := parseKubeconfig(new)
		if err != nil {
			return "", fmt.Errorf("parse new kubeconfig: %w", err)
		}
		NormalizeNames(newConfig, clusterName)
		return serializeKubeconfig(newConfig)
	}

	// Parse both configs
	existingConfig, err := parseKubeconfig(existing)
	if err != nil {
		return "", fmt.Errorf("parse existing kubeconfig: %w", err)
	}

	newConfig, err := parseKubeconfig(new)
	if err != nil {
		return "", fmt.Errorf("parse new kubeconfig: %w", err)
	}

	// Normalize names in new config
	NormalizeNames(newConfig, clusterName)

	// Remove old entries for this cluster from existing config
	existingConfig.Clusters = filterClusters(existingConfig.Clusters, clusterName)
	existingConfig.Contexts = filterContexts(existingConfig.Contexts, clusterName)
	existingConfig.Users = filterUsers(existingConfig.Users, clusterName)

	// Append new entries
	existingConfig.Clusters = append(existingConfig.Clusters, newConfig.Clusters...)
	existingConfig.Contexts = append(existingConfig.Contexts, newConfig.Contexts...)
	existingConfig.Users = append(existingConfig.Users, newConfig.Users...)

	// Ensure required fields
	existingConfig.APIVersion = "v1"
	existingConfig.Kind = "Config"

	// Set current-context to newly added cluster
	existingConfig.CurrentContext = clusterName

	return serializeKubeconfig(existingConfig)
}

// parseKubeconfig parses a YAML kubeconfig string
func parseKubeconfig(data string) (*Config, error) {
	var config Config
	if err := yaml.Unmarshal([]byte(data), &config); err != nil {
		return nil, fmt.Errorf("unmarshal yaml: %w", err)
	}
	return &config, nil
}

// serializeKubeconfig serializes a Config to YAML string
func serializeKubeconfig(config *Config) (string, error) {
	var buf bytes.Buffer
	encoder := yaml.NewEncoder(&buf)
	encoder.SetIndent(2)

	if err := encoder.Encode(config); err != nil {
		return "", fmt.Errorf("encode yaml: %w", err)
	}

	if err := encoder.Close(); err != nil {
		return "", fmt.Errorf("close encoder: %w", err)
	}

	return buf.String(), nil
}

// filterClusters removes clusters with the given name
func filterClusters(clusters []NamedCluster, name string) []NamedCluster {
	filtered := make([]NamedCluster, 0, len(clusters))
	for _, cluster := range clusters {
		if cluster.Name != name {
			filtered = append(filtered, cluster)
		}
	}
	return filtered
}

// filterContexts removes contexts with the given name
func filterContexts(contexts []NamedContext, name string) []NamedContext {
	filtered := make([]NamedContext, 0, len(contexts))
	for _, context := range contexts {
		if context.Name != name {
			filtered = append(filtered, context)
		}
	}
	return filtered
}

// filterUsers removes users with the given name
func filterUsers(users []NamedUser, name string) []NamedUser {
	filtered := make([]NamedUser, 0, len(users))
	for _, user := range users {
		if user.Name != name {
			filtered = append(filtered, user)
		}
	}
	return filtered
}
