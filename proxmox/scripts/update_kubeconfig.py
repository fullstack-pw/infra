#!/usr/bin/env python3
"""
Script to update kubeconfig in Vault with a new cluster configuration.
Simple and focused: merge kubeconfig and update vault secret.
"""

import sys
import logging
import argparse
from pathlib import Path

try:
    import yaml
    import hvac
except ImportError as e:
    print(f"Missing required dependency: {e}")
    print("Install with: pip install pyyaml hvac")
    sys.exit(1)


class KubeconfigUpdater:
    """Simple kubeconfig updater for Vault"""
    
    def __init__(self, vault_addr: str, vault_token: str):
        self.vault_addr = vault_addr
        self.vault_token = vault_token
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
    
    def read_kubeconfig_file(self, file_path: str, host_address: str = None) -> str:
        """Read kubeconfig file and optionally replace localhost"""
        if not Path(file_path).exists():
            raise FileNotFoundError(f"Kubeconfig file not found: {file_path}")
            
        with open(file_path, 'r') as f:
            content = f.read()
            
        if host_address:
            self.logger.info(f"Replacing 127.0.0.1/localhost with {host_address}")
            content = content.replace('127.0.0.1', host_address)
            content = content.replace('localhost', host_address)
            
        return content
    
    def get_vault_secret(self, vault_path: str, key: str = "KUBECONFIG") -> str:
        """Get existing kubeconfig from Vault"""
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
        """Merge new cluster config into existing kubeconfig"""
        if not existing:
            self.logger.info("No existing config - using new config")
            return new
            
        try:
            existing_yaml = yaml.safe_load(existing)
            new_yaml = yaml.safe_load(new)
            
            # Update names in new config
            for section in ['clusters', 'contexts', 'users']:
                if section in new_yaml and new_yaml[section]:
                    for item in new_yaml[section]:
                        item['name'] = cluster_name
                        
                    # Update context references
                    if section == 'contexts':
                        for item in new_yaml[section]:
                            if 'context' in item:
                                item['context']['cluster'] = cluster_name
                                item['context']['user'] = cluster_name
            
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
            
            # Update current-context if provided
            if 'current-context' in new_yaml:
                existing_yaml['current-context'] = new_yaml['current-context']
            
            self.logger.info(f"Successfully merged config for cluster: {cluster_name}")
            return yaml.dump(existing_yaml, default_flow_style=False)
            
        except Exception as e:
            self.logger.error(f"Error merging configs: {e}")
            self.logger.info("Using new config only")
            return new
    
    def update_vault_secret(self, vault_path: str, kubeconfig: str, key: str = "KUBECONFIG") -> bool:
        """Update kubeconfig in Vault secret"""
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
    
    def update_kubeconfig(self, kubeconfig_file: str, vault_path: str, 
                         cluster_name: str, host_address: str = None, 
                         vault_key: str = "KUBECONFIG") -> bool:
        """Main method to update kubeconfig in Vault"""
        try:
            # Read new kubeconfig
            new_config = self.read_kubeconfig_file(kubeconfig_file, host_address)
            
            # Get existing config from Vault
            existing_config = self.get_vault_secret(vault_path, vault_key)
            
            # Merge configs
            merged_config = self.merge_kubeconfig(existing_config, new_config, cluster_name)
            
            # Update Vault
            return self.update_vault_secret(vault_path, merged_config, vault_key)
            
        except Exception as e:
            self.logger.error(f"Update failed: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description='Update kubeconfig in Vault')
    parser.add_argument('--cluster-name', required=True, 
                       help='Name of the Kubernetes cluster')
    parser.add_argument('--kubeconfig-file', required=True, 
                       help='Path to the kubeconfig file to merge')
    parser.add_argument('--vault-path', required=True,
                       help='Vault secret path (format: mount_point/secret_path)')
    parser.add_argument('--vault-addr', required=True, 
                       help='Vault server address')
    parser.add_argument('--vault-token', required=True, 
                       help='Vault token')
    parser.add_argument('--vault-key', default='KUBECONFIG',
                       help='Key name in vault secret (default: KUBECONFIG)')
    parser.add_argument('--host-address', 
                       help='Host address to replace 127.0.0.1 with')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    
    args = parser.parse_args()
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create updater and run
    updater = KubeconfigUpdater(args.vault_addr, args.vault_token)
    
    success = updater.update_kubeconfig(
        kubeconfig_file=args.kubeconfig_file,
        vault_path=args.vault_path,
        cluster_name=args.cluster_name,
        host_address=args.host_address,
        vault_key=args.vault_key
    )
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()