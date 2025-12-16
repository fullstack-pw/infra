package main

import (
	"context"
	"fmt"
	"os"

	"github.com/fullstackpw/infra/cicd-update-kubeconfig/internal/kubeconfig"
	"github.com/fullstackpw/infra/cicd-update-kubeconfig/internal/kubectl"
	"github.com/fullstackpw/infra/cicd-update-kubeconfig/internal/logger"
	"github.com/fullstackpw/infra/cicd-update-kubeconfig/internal/retry"
	"github.com/fullstackpw/infra/cicd-update-kubeconfig/internal/vault"
	"github.com/spf13/cobra"
)

// Options holds command-line options
type Options struct {
	ClusterName        string
	Namespace          string
	VaultPath          string
	VaultAddr          string
	VaultKey           string
	ManagementContext  string
	SkipReadinessCheck bool
	DryRun             bool
	Debug              bool
	Operation          string
}

// Exit codes
const (
	ExitSuccess = iota
	ExitGeneralError
	ExitConfigError
	ExitClusterNotReady
	ExitVaultAuthFailed
	ExitContextNotFound
)

func main() {
	var opts Options

	rootCmd := &cobra.Command{
		Use:   "cicd-update-kubeconfig",
		Short: "Manage Talos cluster kubeconfigs in Vault",
		Long:  `A tool to extract Talos cluster kubeconfigs from Cluster API and manage them in HashiCorp Vault.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return run(cmd.Context(), opts)
		},
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	// Define flags matching Python script
	rootCmd.Flags().StringVar(&opts.ClusterName, "cluster-name", "", "Cluster name (required)")
	rootCmd.Flags().StringVar(&opts.Namespace, "namespace", "clusters", "Namespace where cluster is deployed")
	rootCmd.Flags().StringVar(&opts.VaultPath, "vault-path", "", "Vault secret path in format mount/path (required)")
	rootCmd.Flags().StringVar(&opts.VaultAddr, "vault-addr", "", "Vault server address (required)")
	rootCmd.Flags().StringVar(&opts.VaultKey, "vault-key", "KUBECONFIG", "Key name in vault secret")
	rootCmd.Flags().StringVar(&opts.ManagementContext, "management-context", "", "Kubectl context for management cluster (required)")
	rootCmd.Flags().BoolVar(&opts.SkipReadinessCheck, "skip-readiness-check", false, "Skip cluster readiness check")
	rootCmd.Flags().BoolVar(&opts.DryRun, "dry-run", false, "Simulate without updating Vault")
	rootCmd.Flags().BoolVar(&opts.Debug, "debug", false, "Enable debug logging")
	rootCmd.Flags().StringVar(&opts.Operation, "operation", "upsert", "Operation: upsert or delete")

	rootCmd.MarkFlagRequired("cluster-name")
	rootCmd.MarkFlagRequired("vault-path")
	rootCmd.MarkFlagRequired("vault-addr")
	rootCmd.MarkFlagRequired("management-context")

	if err := rootCmd.Execute(); err != nil {
		exitCode := getExitCode(err)
		os.Exit(exitCode)
	}
}

func run(ctx context.Context, opts Options) error {
	// Setup logger
	log := logger.New(opts.Debug)

	// Validate TF_VAR_VAULT_TOKEN
	vaultToken := os.Getenv("TF_VAR_VAULT_TOKEN")
	if vaultToken == "" {
		log.Error("TF_VAR_VAULT_TOKEN environment variable is required")
		return fmt.Errorf("TF_VAR_VAULT_TOKEN not set")
	}

	// Override operation from env if set
	if envOp := os.Getenv("OPERATION"); envOp != "" {
		opts.Operation = envOp
	}

	log.Info("Starting kubeconfig management for cluster: %s", opts.ClusterName)
	log.Debug("Options: namespace=%s, vault-path=%s, operation=%s", opts.Namespace, opts.VaultPath, opts.Operation)

	// Execute operation
	switch opts.Operation {
	case "upsert", "create", "update":
		return upsertCluster(ctx, opts, vaultToken, log)
	case "delete":
		return deleteCluster(ctx, opts, vaultToken, log)
	default:
		return fmt.Errorf("invalid operation: %s (must be upsert or delete)", opts.Operation)
	}
}

func upsertCluster(ctx context.Context, opts Options, vaultToken string, log *logger.Logger) error {
	// Initialize clients
	kubectlClient := kubectl.NewClient(os.Getenv("KUBECONFIG"))

	vaultClient, err := vault.NewClient(opts.VaultAddr, vaultToken, opts.VaultPath)
	if err != nil {
		log.Error("Failed to initialize Vault client: %v", err)
		return &VaultAuthError{Msg: err.Error()}
	}
	defer vaultClient.Close()

	// 1. Validate and switch to management context
	log.Info("Switching to management context: %s", opts.ManagementContext)
	contexts, err := kubectlClient.ListContexts(ctx)
	if err != nil {
		log.Error("Failed to list kubectl contexts: %v", err)
		return err
	}

	contextFound := false
	for _, c := range contexts {
		if c == opts.ManagementContext {
			contextFound = true
			break
		}
	}

	if !contextFound {
		log.Error("Context %s not found in kubeconfig", opts.ManagementContext)
		log.Debug("Available contexts: %v", contexts)
		return &ContextNotFoundError{Context: opts.ManagementContext}
	}

	if err := kubectlClient.SetContext(ctx, opts.ManagementContext); err != nil {
		log.Error("Failed to set context: %v", err)
		return err
	}

	// 2. Check cluster readiness (optional)
	if !opts.SkipReadinessCheck {
		phase, err := kubectlClient.GetClusterPhase(ctx, opts.ClusterName, opts.Namespace)
		if err != nil {
			log.Warn("Could not check cluster status: %v", err)
		} else {
			log.Info("Cluster %s phase: %s", opts.ClusterName, phase)
			if phase != "Provisioned" {
				log.Warn("Cluster is not in Provisioned state (phase=%s), continuing anyway", phase)
			}
		}
	}

	// 3. Extract kubeconfig with retry
	log.Info("Extracting kubeconfig from secret %s-kubeconfig", opts.ClusterName)
	var newKubeconfig string
	retryCfg := retry.DefaultConfig()

	err = retry.Do(func() error {
		var extractErr error
		newKubeconfig, extractErr = kubectlClient.ExtractKubeconfig(ctx, opts.ClusterName, opts.Namespace)
		return extractErr
	}, retryCfg, func(n uint, err error) {
		log.Warn("Attempt %d/%d failed: %v. Retrying in %v...", n+1, retryCfg.Attempts, err, retryCfg.Delay)
	})

	if err != nil {
		log.Error("Failed to extract kubeconfig after %d attempts: %v", retryCfg.Attempts, err)
		// Check error type
		if _, ok := err.(*kubectl.ClusterNotReadyError); ok {
			return &ClusterNotReadyError{Msg: err.Error()}
		}
		return err
	}

	log.Info("Successfully extracted kubeconfig")

	// 4. Get existing kubeconfig from Vault
	log.Info("Reading existing kubeconfig from Vault")
	existingKubeconfig, err := vaultClient.GetSecret(ctx, opts.VaultKey)
	if err != nil {
		if _, ok := err.(*vault.SecretNotFoundError); ok {
			log.Info("No existing kubeconfig found in Vault - will create new one")
			existingKubeconfig = ""
		} else {
			log.Error("Failed to read from Vault: %v", err)
			return err
		}
	} else {
		log.Info("Found existing kubeconfig in Vault")
	}

	// 5. Merge configs
	log.Info("Merging kubeconfig for cluster: %s", opts.ClusterName)
	mergedKubeconfig, err := kubeconfig.Merge(existingKubeconfig, newKubeconfig, opts.ClusterName)
	if err != nil {
		log.Error("Failed to merge kubeconfigs: %v", err)
		return err
	}

	// 6. Update Vault
	if opts.DryRun {
		log.Info("[DRY RUN] Would update Vault at: %s", opts.VaultPath)
		log.Info("[DRY RUN] Kubeconfig preview (first 200 chars):")
		preview := mergedKubeconfig
		if len(preview) > 200 {
			preview = preview[:200] + "..."
		}
		log.Info("%s", preview)
		return nil
	}

	log.Info("Updating kubeconfig in Vault")
	if err := vaultClient.PutSecret(ctx, opts.VaultKey, mergedKubeconfig); err != nil {
		log.Error("Failed to update Vault: %v", err)
		return err
	}

	log.Info("Successfully updated kubeconfig for cluster: %s", opts.ClusterName)
	return nil
}

func deleteCluster(ctx context.Context, opts Options, vaultToken string, log *logger.Logger) error {
	// Initialize Vault client
	vaultClient, err := vault.NewClient(opts.VaultAddr, vaultToken, opts.VaultPath)
	if err != nil {
		log.Error("Failed to initialize Vault client: %v", err)
		return &VaultAuthError{Msg: err.Error()}
	}
	defer vaultClient.Close()

	// 1. Get existing kubeconfig from Vault
	log.Info("Reading existing kubeconfig from Vault")
	existingKubeconfig, err := vaultClient.GetSecret(ctx, opts.VaultKey)
	if err != nil {
		if _, ok := err.(*vault.SecretNotFoundError); ok {
			log.Info("No kubeconfig found in Vault - nothing to delete (idempotent)")
			return nil
		}
		log.Error("Failed to read from Vault: %v", err)
		return err
	}

	// 2. Delete cluster from config
	log.Info("Deleting cluster %s from kubeconfig", opts.ClusterName)
	updatedKubeconfig, err := kubeconfig.Delete(existingKubeconfig, opts.ClusterName)
	if err != nil {
		log.Error("Failed to delete cluster from kubeconfig: %v", err)
		return err
	}

	// Check if anything changed (cluster was found)
	if updatedKubeconfig == existingKubeconfig {
		log.Info("Cluster %s not found in kubeconfig - nothing to delete (idempotent)", opts.ClusterName)
		return nil
	}

	// 3. Update Vault with modified config
	if opts.DryRun {
		log.Info("[DRY RUN] Would delete cluster: %s", opts.ClusterName)
		log.Info("[DRY RUN] Updated kubeconfig preview (first 200 chars):")
		preview := updatedKubeconfig
		if len(preview) > 200 {
			preview = preview[:200] + "..."
		}
		log.Info("%s", preview)
		return nil
	}

	log.Info("Updating Vault with modified kubeconfig")
	if err := vaultClient.PutSecret(ctx, opts.VaultKey, updatedKubeconfig); err != nil {
		log.Error("Failed to update Vault: %v", err)
		return err
	}

	log.Info("Successfully deleted cluster: %s", opts.ClusterName)
	return nil
}

// Custom error types
type VaultAuthError struct{ Msg string }
type ClusterNotReadyError struct{ Msg string }
type ContextNotFoundError struct{ Context string }

func (e *VaultAuthError) Error() string       { return fmt.Sprintf("vault auth failed: %s", e.Msg) }
func (e *ClusterNotReadyError) Error() string { return fmt.Sprintf("cluster not ready: %s", e.Msg) }
func (e *ContextNotFoundError) Error() string { return fmt.Sprintf("context not found: %s", e.Context) }

// getExitCode determines the exit code from the error type
func getExitCode(err error) int {
	switch err.(type) {
	case *VaultAuthError:
		return ExitVaultAuthFailed
	case *ClusterNotReadyError:
		return ExitClusterNotReady
	case *ContextNotFoundError:
		return ExitContextNotFound
	default:
		return ExitGeneralError
	}
}
