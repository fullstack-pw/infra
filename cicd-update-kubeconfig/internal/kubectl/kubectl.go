package kubectl

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"os/exec"
	"strings"
)

// Client handles kubectl operations
type Client struct {
	kubeconfigPath string
}

// NewClient creates a new kubectl client
func NewClient(kubeconfigPath string) *Client {
	if kubeconfigPath == "" {
		kubeconfigPath = "" // kubectl will use default
	}
	return &Client{
		kubeconfigPath: kubeconfigPath,
	}
}

// ListContexts returns available kubeconfig contexts
func (c *Client) ListContexts(ctx context.Context) ([]string, error) {
	args := []string{"config", "get-contexts", "-o", "name"}
	if c.kubeconfigPath != "" {
		args = append([]string{"--kubeconfig", c.kubeconfigPath}, args...)
	}

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("kubectl get-contexts failed: %w: %s", err, output)
	}

	contexts := strings.Split(strings.TrimSpace(string(output)), "\n")
	return contexts, nil
}

// SetContext switches to the specified kubeconfig context
func (c *Client) SetContext(ctx context.Context, contextName string) error {
	args := []string{"config", "use-context", contextName}
	if c.kubeconfigPath != "" {
		args = append([]string{"--kubeconfig", c.kubeconfigPath}, args...)
	}

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("kubectl use-context failed: %w: %s", err, output)
	}

	return nil
}

// ExtractKubeconfig extracts kubeconfig from Cluster API secret
// Secret name format: {cluster-name}-kubeconfig
// Data field: .data.value (base64 encoded)
func (c *Client) ExtractKubeconfig(ctx context.Context, clusterName, namespace string) (string, error) {
	secretName := fmt.Sprintf("%s-kubeconfig", clusterName)

	args := []string{
		"get", "secret", secretName,
		"-n", namespace,
		"-o", "jsonpath={.data.value}",
	}
	if c.kubeconfigPath != "" {
		args = append([]string{"--kubeconfig", c.kubeconfigPath}, args...)
	}

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		stderrStr := stderr.String()
		if strings.Contains(stderrStr, "NotFound") || strings.Contains(stderrStr, "not found") {
			return "", &ClusterNotReadyError{
				ClusterName: clusterName,
				Namespace:   namespace,
				Msg:         "secret not found - cluster may not be ready yet",
			}
		}
		if strings.Contains(stderrStr, "connection refused") || strings.Contains(stderrStr, "Unable to connect") {
			return "", &KubectlConnectionError{
				Msg: fmt.Sprintf("cannot connect to management cluster: %s", stderrStr),
			}
		}
		return "", fmt.Errorf("kubectl get secret failed: %w: %s", err, stderrStr)
	}

	kubeconfigB64 := stdout.String()
	if kubeconfigB64 == "" {
		return "", fmt.Errorf("secret %s exists but has no data", secretName)
	}

	// Decode base64
	decoded, err := base64.StdEncoding.DecodeString(kubeconfigB64)
	if err != nil {
		return "", fmt.Errorf("base64 decode failed: %w", err)
	}

	return string(decoded), nil
}

// GetClusterPhase returns the Cluster API cluster phase
func (c *Client) GetClusterPhase(ctx context.Context, clusterName, namespace string) (string, error) {
	args := []string{
		"get", "cluster", clusterName,
		"-n", namespace,
		"-o", "jsonpath={.status.phase}",
	}
	if c.kubeconfigPath != "" {
		args = append([]string{"--kubeconfig", c.kubeconfigPath}, args...)
	}

	cmd := exec.CommandContext(ctx, "kubectl", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("kubectl get cluster failed: %w: %s", err, output)
	}

	return strings.TrimSpace(string(output)), nil
}

// ClusterNotReadyError indicates the cluster is not ready
type ClusterNotReadyError struct {
	ClusterName string
	Namespace   string
	Msg         string
}

func (e *ClusterNotReadyError) Error() string {
	return fmt.Sprintf("cluster %s not ready: %s", e.ClusterName, e.Msg)
}

// KubectlConnectionError indicates kubectl cannot connect to the cluster
type KubectlConnectionError struct {
	Msg string
}

func (e *KubectlConnectionError) Error() string {
	return fmt.Sprintf("kubectl connection error: %s", e.Msg)
}
