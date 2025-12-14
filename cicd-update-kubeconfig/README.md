# cicd-update-kubeconfig

A Go tool to extract Talos cluster kubeconfigs from Cluster API and manage them in HashiCorp Vault.

## Overview

This tool replaces the Python script for managing kubeconfigs in CI/CD workflows. It:
- Extracts kubeconfigs from Cluster API secrets
- Merges them into a single kubeconfig stored in Vault
- Supports CREATE, UPDATE, and DELETE operations
- Implements retry logic for cluster readiness
- Preserves other keys in Vault secrets

## Features

- **Drop-in Replacement**: Compatible CLI arguments with the Python script
- **Single Merged Kubeconfig**: Maintains one kubeconfig in Vault with all clusters
- **Fail-Fast**: Exits immediately on errors for reliable CI/CD
- **Idempotent**: Safe to run multiple times
- **Dry-Run Mode**: Test changes without updating Vault
- **Structured Logging**: Clear, informative output

## Installation

### Build from Source

```bash
cd cicd-update-kubeconfig
go build -o cicd-update-kubeconfig ./cmd/cicd-update-kubeconfig
```

### Using Makefile

From the repository root:

```bash
make build-kubeconfig-tool
```

## Usage

### Basic Usage

```bash
cicd-update-kubeconfig \
  --cluster-name dev \
  --namespace dev \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.fullstack.pw \
  --management-context tools
```

### Environment Variables

- `VAULT_TOKEN` (required): Vault authentication token
- `KUBECONFIG` (optional): Path to kubeconfig file (default: `~/.kube/config`)
- `OPERATION` (optional): Override operation mode (`upsert` or `delete`)

### Command-Line Flags

| Flag | Description | Required | Default |
|------|-------------|----------|---------|
| `--cluster-name` | Name of the cluster | Yes | - |
| `--namespace` | Namespace where cluster is deployed | No | `clusters` |
| `--vault-path` | Vault secret path (format: `mount/path`) | Yes | - |
| `--vault-addr` | Vault server address | Yes | - |
| `--vault-key` | Key name in Vault secret | No | `KUBECONFIG` |
| `--management-context` | Kubectl context for management cluster | Yes | - |
| `--operation` | Operation mode: `upsert` or `delete` | No | `upsert` |
| `--skip-readiness-check` | Skip cluster readiness validation | No | `false` |
| `--dry-run` | Simulate without updating Vault | No | `false` |
| `--debug` | Enable debug logging | No | `false` |

### Operations

#### UPSERT (Create/Update)

Adds or updates a cluster in the merged kubeconfig:

```bash
cicd-update-kubeconfig \
  --cluster-name prod \
  --namespace prod \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.example.com \
  --management-context tools \
  --operation upsert
```

**Process:**
1. Validates management context exists
2. Checks cluster readiness (unless `--skip-readiness-check`)
3. Extracts kubeconfig from Cluster API secret (with retry)
4. Merges into existing kubeconfig from Vault
5. Updates Vault secret

#### DELETE

Removes a cluster from the merged kubeconfig:

```bash
OPERATION=delete cicd-update-kubeconfig \
  --cluster-name old-cluster \
  --namespace old-cluster \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.example.com \
  --management-context tools \
  --skip-readiness-check
```

**Process:**
1. Retrieves existing kubeconfig from Vault
2. Removes cluster entries (idempotent if not found)
3. Updates `current-context` if necessary
4. Updates Vault secret

### Dry-Run Mode

Test operations without modifying Vault:

```bash
cicd-update-kubeconfig \
  --cluster-name test \
  --namespace test \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.example.com \
  --management-context tools \
  --dry-run
```

## CI/CD Integration

### GitHub Actions

The tool is integrated into the Terraform apply workflow:

```yaml
- name: Setup Go
  uses: actions/setup-go@v5
  with:
    go-version: '1.22'

- name: Build kubeconfig manager
  run: |
    cd cicd-update-kubeconfig
    go build -o ../cicd-update-kubeconfig ./cmd/cicd-update-kubeconfig

- name: Update Kubeconfigs in Vault
  env:
    VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
    VAULT_ADDR: https://vault.fullstack.pw
  run: |
    # Upsert clusters
    for cluster in $(terraform output -json proxmox_talos_cluster_names | jq -r '.[]'); do
      ./cicd-update-kubeconfig \
        --cluster-name "$cluster" \
        --namespace "$cluster" \
        --vault-path "kv/cluster-secret-store/secrets" \
        --vault-addr "$VAULT_ADDR" \
        --management-context "$workspace"
    done
```

### Makefile

Update kubeconfigs for all environments:

```bash
make update-kubeconfigs
```

Update for specific environment:

```bash
make update-kubeconfigs ENV=tools
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration error (missing arguments) |
| 3 | Cluster not ready (after retries) |
| 4 | Vault authentication failed |
| 5 | Kubectl context not found |

## Architecture

### Package Structure

```
cicd-update-kubeconfig/
├── cmd/
│   └── cicd-update-kubeconfig/
│       └── main.go              # CLI entry point
├── internal/
│   ├── kubectl/
│   │   └── kubectl.go           # Kubectl secret extraction
│   ├── kubeconfig/
│   │   ├── types.go             # Kubeconfig data structures
│   │   ├── merge.go             # Merge algorithm
│   │   ├── delete.go            # Delete algorithm
│   │   └── normalize.go         # Name normalization
│   ├── vault/
│   │   └── client.go            # Vault KV v2 operations
│   ├── retry/
│   │   └── retry.go             # Retry logic with backoff
│   └── logger/
│       └── logger.go            # Structured logging
├── go.mod
└── go.sum
```

### Key Components

- **kubectl**: Extracts secrets from Cluster API using `kubectl` commands
- **kubeconfig**: Parses, merges, and deletes kubeconfig entries
- **vault**: Interacts with Vault KV v2 secrets engine
- **retry**: Implements retry logic with fixed delay (3 attempts, 30s intervals)
- **logger**: Provides structured logging with debug support

## How It Works

### Merge Algorithm

1. Parse existing kubeconfig from Vault (if exists)
2. Parse new kubeconfig from Cluster API secret
3. Normalize all names in new config to use cluster name
4. Remove old entries for this cluster from existing config
5. Append new entries to existing config
6. Set `current-context` to newly added cluster
7. Return merged YAML

### Delete Algorithm

1. Parse existing kubeconfig from Vault
2. Filter out all entries with matching cluster name
3. If `current-context` was the deleted cluster:
   - Set to first available cluster (if any)
   - Otherwise clear `current-context`
4. Return updated YAML (idempotent if cluster not found)

### Name Normalization

All names are set to the cluster name for consistency:
- Cluster name: `{cluster-name}`
- User name: `{cluster-name}`
- Context name: `{cluster-name}`
- Context references: `{cluster-name}`

## Vault Integration

- **KV Version**: v2
- **Path Format**: `mount_point/secret_path` (e.g., `kv/cluster-secret-store/secrets`)
- **Authentication**: Token-based via `VAULT_TOKEN` environment variable
- **Key Preservation**: Other keys in the secret are preserved during updates

## Error Handling

- **Fail-Fast**: Exits immediately on first error
- **Retry Logic**: Cluster API secret extraction retries 3 times (30s intervals)
- **Idempotency**: Delete operations succeed even if cluster not found
- **Clear Errors**: Meaningful error messages with exit codes

## Troubleshooting

### Cluster Not Ready Error

```
ERROR: cluster dev not ready: secret not found - cluster may not be ready yet
```

**Solution**: Wait for cluster provisioning or use `--skip-readiness-check`

### Context Not Found

```
ERROR: context tools not found in kubeconfig
```

**Solution**: Verify the management context name and kubeconfig file

### Vault Authentication Failed

```
ERROR: vault auth failed: ...
```

**Solution**: Check `VAULT_TOKEN` environment variable

## Development

### Dependencies

```bash
go mod download
```

### Build

```bash
go build -o cicd-update-kubeconfig ./cmd/cicd-update-kubeconfig
```

### Testing

```bash
# Dry-run mode for safe testing
./cicd-update-kubeconfig \
  --cluster-name test \
  --namespace test \
  --vault-path kv/test \
  --vault-addr https://vault.example.com \
  --management-context tools \
  --dry-run \
  --debug
```

## Migration from Python Script

The Go tool is a drop-in replacement for `/home/pedro/repos/infra/clusters/scripts/update_talos_kubeconfig.py`.

**Changes:**
- Same CLI arguments (100% compatible)
- Faster execution (no Python interpreter overhead)
- Better error handling with typed errors
- Built-in retry logic
- Supports DELETE operations

**Python Script (deprecated):**
```bash
python3 scripts/update_talos_kubeconfig.py \
  --cluster-name dev \
  --namespace dev \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.fullstack.pw \
  --management-context tools
```

**Go Binary (current):**
```bash
./cicd-update-kubeconfig \
  --cluster-name dev \
  --namespace dev \
  --vault-path kv/cluster-secret-store/secrets \
  --vault-addr https://vault.fullstack.pw \
  --management-context tools
```

## License

See repository LICENSE file.

## Contributing

1. Make changes in the `cicd-update-kubeconfig/` directory
2. Build and test: `make build-kubeconfig-tool`
3. Test with `--dry-run` flag first
4. Submit pull request

## Support

For issues or questions:
- Check the [main repository README](../README.md)
- Review the [plan document](../.claude/plans/piped-moseying-swing.md)
- Open an issue in the repository
