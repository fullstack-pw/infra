package vault

import (
	"context"
	"fmt"
	"strings"

	vault "github.com/hashicorp/vault-client-go"
	"github.com/hashicorp/vault-client-go/schema"
)

// Client handles Vault KV v2 operations
type Client struct {
	client     *vault.Client
	mountPoint string
	secretPath string
}

// NewClient creates a new Vault client
// vaultPath format: "kv/cluster-secret-store/secrets"
// mountPoint: "kv", secretPath: "cluster-secret-store/secrets"
func NewClient(addr, token, vaultPath string) (*Client, error) {
	// Parse vault path
	mountPoint, secretPath, err := ParseVaultPath(vaultPath)
	if err != nil {
		return nil, err
	}

	// Create Vault client
	vaultClient, err := vault.New(
		vault.WithAddress(addr),
		vault.WithRequestTimeout(30),
	)
	if err != nil {
		return nil, fmt.Errorf("create vault client: %w", err)
	}

	// Set token
	if err := vaultClient.SetToken(token); err != nil {
		return nil, fmt.Errorf("set vault token: %w", err)
	}

	return &Client{
		client:     vaultClient,
		mountPoint: mountPoint,
		secretPath: secretPath,
	}, nil
}

// GetSecret retrieves a secret value from KV v2
func (c *Client) GetSecret(ctx context.Context, key string) (string, error) {
	resp, err := c.client.Secrets.KvV2Read(ctx, c.secretPath, vault.WithMountPath(c.mountPoint))
	if err != nil {
		// Check if it's a 404 (secret not found)
		if strings.Contains(err.Error(), "404") {
			return "", &SecretNotFoundError{Path: c.secretPath}
		}
		return "", fmt.Errorf("vault read failed: %w", err)
	}

	if resp == nil || resp.Data.Data == nil {
		return "", &SecretNotFoundError{Path: c.secretPath}
	}

	value, ok := resp.Data.Data[key].(string)
	if !ok {
		return "", fmt.Errorf("key %s not found in secret", key)
	}

	return value, nil
}

// PutSecret stores a secret value in KV v2
// Preserves other keys in the secret
func (c *Client) PutSecret(ctx context.Context, key, value string) error {
	// Get existing secret data to preserve other keys
	secretData := map[string]interface{}{key: value}

	resp, err := c.client.Secrets.KvV2Read(ctx, c.secretPath, vault.WithMountPath(c.mountPoint))
	if err == nil && resp != nil && resp.Data.Data != nil {
		// Merge with existing data
		for k, v := range resp.Data.Data {
			if k != key {
				secretData[k] = v
			}
		}
	}

	// Write secret - need to wrap data in schema
	_, err = c.client.Secrets.KvV2Write(ctx, c.secretPath, schema.KvV2WriteRequest{
		Data: secretData,
	}, vault.WithMountPath(c.mountPoint))
	if err != nil {
		return fmt.Errorf("vault write failed: %w", err)
	}

	return nil
}

// Close cleans up client resources
func (c *Client) Close() error {
	// vault-api-go client doesn't require explicit cleanup
	return nil
}

// ParseVaultPath splits "kv/cluster-secret-store/secrets" into mount and path
func ParseVaultPath(fullPath string) (mount, path string, err error) {
	parts := strings.SplitN(fullPath, "/", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("invalid vault path format: %s (expected: mount/path)", fullPath)
	}
	return parts[0], parts[1], nil
}

// SecretNotFoundError indicates the secret was not found in Vault
type SecretNotFoundError struct {
	Path string
}

func (e *SecretNotFoundError) Error() string {
	return fmt.Sprintf("secret not found: %s", e.Path)
}
