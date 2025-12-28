#!/usr/bin/env python3
"""
Script to extract Talos/Cluster API kubeconfigs and update Vault.
Designed for CI/CD workflows that manage multiple Cluster API clusters.
"""

import sys
import os
import logging
import argparse
import subprocess
import base64
import time
from pathlib import Path

try:
    import yaml
    import hvac
except ImportError as e:
    print(f"Missing required dependency: {e}")
    print("Install with: pip install pyyaml hvac")
    sys.exit(1)


class ClusterNotReadyError(Exception):
    """Raised when cluster is not in Provisioned state"""
    pass


class KubectlConnectionError(Exception):
    """Raised when kubectl cannot connect to management cluster"""
    pass


class TalosKubeconfigUpdater:
    """Cluster API Talos kubeconfig updater for Vault"""

    def __init__(self, vault_addr: str, vault_token: str, management_context: str, dry_run: bool = False):
        self.vault_addr = vault_addr
        self.vault_token = vault_token
        self.management_context = management_context
        self.dry_run = dry_run
        self.client = None
        self._setup_logging()

    def _setup_logging(self):
        """Setup basic logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(levelname)s: %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def _get_vault_client(self) -> hvac.Client:
        """Create and return authenticated Vault client"""
        if self.client:
            return self.client

        try:
            self.client = hvac.Client(url=self.vault_addr, token=self.vault_token)
            if not self.client.is_authenticated():
                raise Exception("Failed to authenticate to Vault")
            self.logger.info("Successfully authenticated to Vault")
            return self.client
        except Exception as e:
            self.logger.error(f"Vault connection failed: {e}")
            raise

    def extract_kubeconfig_from_secret(self, cluster_name: str, namespace: str = "clusters") -> str:
        """
        Extract kubeconfig from Cluster API secret using kubectl

        Secret naming: <cluster-name>-kubeconfig
        Data field: .data.value (base64 encoded)
        """
        secret_name = f"{cluster_name}-kubeconfig"

        try:
            # Verify context exists first
            self.logger.info(f"Using management cluster context: {self.management_context}")
            check_context = subprocess.run(
                ["kubectl", "config", "get-contexts", "-o", "name"],
                check=True,
                capture_output=True,
                text=True
            )
            available_contexts = check_context.stdout.strip().split('\n')

            if self.management_context not in available_contexts:
                raise ValueError(f"Context '{self.management_context}' not found in kubeconfig. Available contexts: {', '.join(available_contexts)}")

            # Set context to management cluster
            subprocess.run(
                ["kubectl", "config", "use-context", self.management_context],
                check=True,
                capture_output=True,
                text=True
            )

            self.logger.info(f"Extracting kubeconfig from secret: {secret_name} in namespace: {namespace}")

            # Extract secret using kubectl
            result = subprocess.run(
                [
                    "kubectl", "get", "secret", secret_name,
                    "-n", namespace,
                    "-o", "jsonpath={.data.value}"
                ],
                check=True,
                capture_output=True,
                text=True
            )

            # Decode base64
            kubeconfig_b64 = result.stdout.strip()
            if not kubeconfig_b64:
                raise ValueError(f"Secret {secret_name} exists but has no data")

            kubeconfig = base64.b64decode(kubeconfig_b64).decode('utf-8')
            self.logger.info(f"Successfully extracted kubeconfig for {cluster_name}")

            return kubeconfig

        except subprocess.CalledProcessError as e:
            stderr = e.stderr if e.stderr else ""
            if "NotFound" in stderr or "not found" in stderr:
                self.logger.error(f"Secret {secret_name} not found in namespace {namespace}")
                self.logger.info("Cluster may not be ready yet. Please wait for cluster provisioning to complete.")
                raise ClusterNotReadyError(f"Cluster {cluster_name} secret not found")
            elif "connection refused" in stderr or "Unable to connect" in stderr:
                self.logger.error(f"Cannot connect to management cluster: {stderr}")
                raise KubectlConnectionError("Cannot connect to management cluster")
            else:
                self.logger.error(f"kubectl command failed: {stderr}")
                raise
        except Exception as e:
            self.logger.error(f"Error extracting kubeconfig: {e}")
            raise

    def check_cluster_ready(self, cluster_name: str, namespace: str = "clusters") -> bool:
        """
        Check if Cluster API cluster is ready by checking the Cluster resource
        """
        try:
            result = subprocess.run(
                [
                    "kubectl", "get", "cluster", cluster_name,
                    "-n", namespace,
                    "-o", "jsonpath={.status.phase}"
                ],
                check=True,
                capture_output=True,
                text=True
            )

            phase = result.stdout.strip()
            self.logger.info(f"Cluster {cluster_name} phase: {phase}")

            return phase == "Provisioned"

        except subprocess.CalledProcessError:
            self.logger.warning(f"Could not check cluster status for {cluster_name}")
            return False

    def get_vault_secret(self, vault_path: str, key: str = "KUBECONFIG") -> str:
        """Get existing kubeconfig from Vault"""
        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would read secret from {vault_path}")
            return None

        client = self._get_vault_client()

        # Parse vault path (mount_point/secret_path)
        if '/' not in vault_path:
            raise ValueError(f"Invalid vault path format: {vault_path}. Expected: mount_point/secret_path")

        mount_point, secret_path = vault_path.split('/', 1)

        try:
            self.logger.info(f"Reading secret from {vault_path}")
            secret = client.secrets.kv.v2.read_secret_version(
                path=secret_path,
                mount_point=mount_point
            )

            if secret and 'data' in secret and 'data' in secret['data']:
                kubeconfig = secret['data']['data'].get(key)
                if kubeconfig:
                    self.logger.info("Found existing kubeconfig in Vault")
                    return kubeconfig

        except hvac.exceptions.InvalidPath:
            self.logger.info("No existing secret found - will create new one")
        except Exception as e:
            self.logger.warning(f"Error reading from Vault: {e}")

        return None

    def merge_kubeconfig(self, existing: str, new: str, cluster_name: str) -> str:
        """
        Merge new cluster config into existing kubeconfig

        For Talos clusters:
        - Context name = cluster name (dev, stg, prd)
        - Cluster name = cluster name
        - User name = cluster name
        """
        if not existing:
            self.logger.info("No existing config - using new config")
            # Still need to update naming in new config
            return self._update_kubeconfig_names(new, cluster_name)

        try:
            existing_yaml = yaml.safe_load(existing)
            new_yaml = yaml.safe_load(new)

            # Update names in new config
            new_yaml = self._update_kubeconfig_names_yaml(new_yaml, cluster_name)

            # Merge sections
            for section in ['clusters', 'contexts', 'users']:
                if section not in existing_yaml:
                    existing_yaml[section] = []

                # Remove existing entries for this cluster
                existing_yaml[section] = [
                    item for item in existing_yaml[section]
                    if item.get('name') != cluster_name
                ]

                # Add new entries
                if section in new_yaml and new_yaml[section]:
                    existing_yaml[section].extend(new_yaml[section])

            # Ensure required fields
            existing_yaml.setdefault('apiVersion', 'v1')
            existing_yaml.setdefault('kind', 'Config')

            # Set current-context to the newly added cluster
            existing_yaml['current-context'] = cluster_name

            self.logger.info(f"Successfully merged config for cluster: {cluster_name}")
            return yaml.dump(existing_yaml, default_flow_style=False)

        except Exception as e:
            self.logger.error(f"Error merging configs: {e}")
            raise

    def _update_kubeconfig_names_yaml(self, kubeconfig_yaml: dict, cluster_name: str) -> dict:
        """Update all names in kubeconfig YAML to use cluster name"""
        # Update cluster name
        if 'clusters' in kubeconfig_yaml:
            for cluster in kubeconfig_yaml['clusters']:
                cluster['name'] = cluster_name

        # Update user name
        if 'users' in kubeconfig_yaml:
            for user in kubeconfig_yaml['users']:
                user['name'] = cluster_name

        # Update context name and references
        if 'contexts' in kubeconfig_yaml:
            for context in kubeconfig_yaml['contexts']:
                context['name'] = cluster_name
                if 'context' in context:
                    context['context']['cluster'] = cluster_name
                    context['context']['user'] = cluster_name

        # Update current-context
        kubeconfig_yaml['current-context'] = cluster_name

        return kubeconfig_yaml

    def _update_kubeconfig_names(self, kubeconfig_str: str, cluster_name: str) -> str:
        """Update all names in kubeconfig string to use cluster name"""
        kubeconfig_yaml = yaml.safe_load(kubeconfig_str)
        updated_yaml = self._update_kubeconfig_names_yaml(kubeconfig_yaml, cluster_name)
        return yaml.dump(updated_yaml, default_flow_style=False)

    def update_vault_secret(self, vault_path: str, kubeconfig: str, key: str = "KUBECONFIG") -> bool:
        """Update kubeconfig in Vault secret"""
        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would update Vault at {vault_path}")
            self.logger.info(f"[DRY RUN] Kubeconfig preview (first 200 chars):\n{kubeconfig[:200]}...")
            return True

        client = self._get_vault_client()

        # Parse vault path
        mount_point, secret_path = vault_path.split('/', 1)

        try:
            # Get existing secret data to preserve other keys
            secret_data = {key: kubeconfig}

            try:
                existing = client.secrets.kv.v2.read_secret_version(
                    path=secret_path,
                    mount_point=mount_point
                )
                if existing and 'data' in existing and 'data' in existing['data']:
                    existing_data = existing['data']['data']
                    existing_data.update(secret_data)
                    secret_data = existing_data
            except hvac.exceptions.InvalidPath:
                pass  # Secret doesn't exist, use new data

            # Write secret
            client.secrets.kv.v2.create_or_update_secret(
                path=secret_path,
                secret=secret_data,
                mount_point=mount_point
            )

            self.logger.info(f"Successfully updated secret at {vault_path}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to update Vault secret: {e}")
            return False

    def update_cluster_kubeconfig(self, cluster_name: str, namespace: str,
                                   vault_path: str, vault_key: str = "KUBECONFIG",
                                   skip_readiness_check: bool = False) -> bool:
        """Main method to extract and update kubeconfig for a single cluster"""
        try:
            # Check if cluster is ready (optional)
            if not skip_readiness_check:
                if not self.check_cluster_ready(cluster_name, namespace):
                    self.logger.warning(f"Cluster {cluster_name} is not ready yet")
                    self.logger.info("Attempting to extract kubeconfig anyway...")

            # Extract kubeconfig from Cluster API secret with retry
            new_config = None
            for attempt in range(3):
                try:
                    new_config = self.extract_kubeconfig_from_secret(cluster_name, namespace)
                    break
                except ClusterNotReadyError:
                    if attempt < 2:
                        self.logger.info(f"Retry {attempt + 1}/3 in 30 seconds...")
                        time.sleep(30)
                    else:
                        raise

            if not new_config:
                raise Exception("Failed to extract kubeconfig after retries")

            # Get existing config from Vault
            existing_config = self.get_vault_secret(vault_path, vault_key)

            # Merge configs
            merged_config = self.merge_kubeconfig(existing_config, new_config, cluster_name)

            # Update Vault
            return self.update_vault_secret(vault_path, merged_config, vault_key)

        except Exception as e:
            self.logger.error(f"Update failed for {cluster_name}: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Extract Talos/Cluster API kubeconfig and update Vault'
    )
    parser.add_argument('--cluster-name', required=True,
                       help='Name of the Cluster API cluster')
    parser.add_argument('--namespace', default='clusters',
                       help='Namespace where cluster is deployed (default: clusters)')
    parser.add_argument('--vault-path', required=True,
                       help='Vault secret path (format: mount_point/secret_path)')
    parser.add_argument('--vault-addr', required=True,
                       help='Vault server address')
    parser.add_argument('--vault-key', default='KUBECONFIG',
                       help='Key name in vault secret (default: KUBECONFIG)')
    parser.add_argument('--management-context', required=True,
                       help='Kubectl context for management cluster')
    parser.add_argument('--skip-readiness-check', action='store_true',
                       help='Skip cluster readiness check')
    parser.add_argument('--dry-run', action='store_true',
                       help='Simulate without updating Vault')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')

    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    vault_token = os.getenv('VAULT_TOKEN')
    if not vault_token:
        print("Error: VAULT_TOKEN environment variable is required")
        sys.exit(1)

    updater = TalosKubeconfigUpdater(
        vault_addr=args.vault_addr,
        vault_token=vault_token,
        management_context=args.management_context,
        dry_run=args.dry_run
    )

    success = updater.update_cluster_kubeconfig(
        cluster_name=args.cluster_name,
        namespace=args.namespace,
        vault_path=args.vault_path,
        vault_key=args.vault_key,
        skip_readiness_check=args.skip_readiness_check
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
