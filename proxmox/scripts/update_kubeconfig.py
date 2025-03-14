#!/usr/bin/env python3
"""
Script to update kubeconfig in Vault with a new cluster configuration.
Uses hvac library instead of vault CLI binary.
"""
import os
import sys
import json
import argparse
from pathlib import Path

# Check and install required dependencies
try:
    import yaml
except ImportError:
    print("PyYAML not found. Attempting to install...")
    try:
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml"])
        import yaml
        print("PyYAML successfully installed")
    except Exception as e:
        print(f"Failed to install PyYAML: {e}")
        sys.exit(1)

try:
    import hvac
except ImportError:
    print("HVAC (Hashicorp Vault client) not found. Attempting to install...")
    try:
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "hvac"])
        import hvac
        print("HVAC successfully installed")
    except Exception as e:
        print(f"Failed to install HVAC: {e}")
        sys.exit(1)


def get_vault_client(vault_addr, vault_token):
    """Create and return an authenticated Vault client"""
    try:
        client = hvac.Client(url=vault_addr, token=vault_token)
        if client.is_authenticated():
            print(f"Successfully authenticated to Vault at {vault_addr}")
            return client
        else:
            print(f"Failed to authenticate to Vault at {vault_addr}")
            return None
    except Exception as e:
        print(f"Error connecting to Vault: {e}")
        return None


def get_existing_kubeconfig(client, path="kv/gitlab-runner", key="KUBECONFIG"):
    """Retrieve existing kubeconfig from Vault using hvac"""
    if not client:
        print("No valid Vault client provided")
        return None
    
    print(f"Retrieving existing kubeconfig from Vault at {path}")
    
    try:
        # Extract mount point and path
        mount_point, secret_path = path.split('/', 1) if '/' in path else (path, '')
        
        # Read the secret
        try:
            secret = client.secrets.kv.v2.read_secret_version(
                path=secret_path,
                mount_point=mount_point
            )
            if secret and 'data' in secret and 'data' in secret['data']:
                kubeconfig = secret['data']['data'].get(key)
                if kubeconfig:
                    print(f"Successfully retrieved existing kubeconfig from Vault")
                    # Print the first 100 chars to verify
                    print(f"Kubeconfig starts with: {kubeconfig[:100]}...")
                    return kubeconfig
                else:
                    print(f"No kubeconfig found in Vault at {path}")
            else:
                print(f"No data found in Vault response for {path}")
                print(f"Vault response structure: {secret.keys() if secret else 'None'}")
            return None
        except hvac.exceptions.InvalidPath:
            print(f"Secret not found at {mount_point}/{secret_path}")
            return None
            
    except Exception as e:
        print(f"Error reading from Vault: {e}")
        print(f"Checking if secret engine exists...")
        try:
            # List mounts to check if the secret engine exists
            mounts = client.sys.list_mounted_secrets_engines()
            print(f"Available secret engines: {list(mounts.keys())}")
            
            if f"{mount_point}/" in mounts:
                print(f"Secret engine {mount_point} exists")
            else:
                print(f"Secret engine {mount_point} does not exist")
        except Exception as mount_error:
            print(f"Error listing secret engines: {mount_error}")
        return None


def update_vault_kubeconfig(client, kubeconfig, path="kv/gitlab-runner", key="KUBECONFIG"):
    """Update kubeconfig in Vault using hvac"""
    if not client:
        print("No valid Vault client provided")
        return False
    
    print(f"Updating kubeconfig in Vault at {path}")
    
    try:
        # Extract mount point and path
        mount_point, secret_path = path.split('/', 1) if '/' in path else (path, '')
        
        # Prepare the data to write
        secret_data = {key: kubeconfig}
        
        # Try to read existing data to merge with new data
        try:
            existing_secret = client.secrets.kv.v2.read_secret_version(
                path=secret_path,
                mount_point=mount_point
            )
            if existing_secret and 'data' in existing_secret and 'data' in existing_secret['data']:
                # Merge existing data with new data
                existing_data = existing_secret['data']['data']
                print(f"Retrieved existing data with keys: {list(existing_data.keys())}")
                existing_data.update(secret_data)
                secret_data = existing_data
        except hvac.exceptions.InvalidPath:
            # Secret doesn't exist yet, just use the new data
            print(f"Creating new secret at {mount_point}/{secret_path}")
        
        # Write the secret
        client.secrets.kv.v2.create_or_update_secret(
            path=secret_path,
            secret=secret_data,
            mount_point=mount_point
        )
        
        print(f"Successfully updated kubeconfig in Vault at {path}")
        return True
        
    except Exception as e:
        print(f"Error updating Vault: {e}")
        return False


def merge_kubeconfig(existing_config, new_config, cluster_name):
    """Merge the new cluster config into the existing kubeconfig"""
    if not existing_config:
        print("No existing kubeconfig, using the new one directly")
        return new_config
    
    print(f"Merging kubeconfig for cluster: {cluster_name}")
    
    try:
        existing_yaml = yaml.safe_load(existing_config)
        new_yaml = yaml.safe_load(new_config)
        
        # Update cluster name, context, and user references
        for section in ['clusters', 'contexts', 'users']:
            if section in new_yaml and len(new_yaml[section]) > 0:
                item = new_yaml[section][0]
                print(f"Updating {section} name to {cluster_name}")
                item['name'] = cluster_name
                
                # For contexts, also update the references
                if section == 'contexts' and 'context' in item:
                    item['context']['cluster'] = cluster_name
                    item['context']['user'] = cluster_name
        
        # Merge the sections
        for section in ['clusters', 'contexts', 'users']:
            if section not in existing_yaml:
                existing_yaml[section] = []
            
            # Remove any existing entries with the same name
            existing_yaml[section] = [
                item for item in existing_yaml[section] 
                if item.get('name') != cluster_name
            ]
            
            # Add the new entries
            if section in new_yaml:
                existing_yaml[section].extend(new_yaml[section])
        
        # Ensure apiVersion and kind are set
        if 'apiVersion' not in existing_yaml:
            existing_yaml['apiVersion'] = new_yaml.get('apiVersion', 'v1')
        if 'kind' not in existing_yaml:
            existing_yaml['kind'] = new_yaml.get('kind', 'Config')
        
        # Keep current-context if it exists
        if 'current-context' not in existing_yaml and 'current-context' in new_yaml:
            existing_yaml['current-context'] = new_yaml['current-context']
        
        print("Successfully merged kubeconfig")
        return yaml.dump(existing_yaml, default_flow_style=False)
    
    except Exception as e:
        print(f"Error merging kubeconfig: {e}")
        print("Falling back to using the new config only")
        return new_config


def update_cluster_secret_store(client, kubeconfig):
    """Update the cluster-secret-store with the same kubeconfig"""
    path = "kv/cluster-secret-store/secrets/KUBECONFIG"
    print(f"Updating cluster secret store at {path}")
    return update_vault_kubeconfig(client, kubeconfig, path, "KUBECONFIG")


def main():
    parser = argparse.ArgumentParser(description='Update kubeconfig in Vault')
    parser.add_argument('--cluster-name', required=True, help='Name of the Kubernetes cluster')
    parser.add_argument('--kubeconfig-file', required=True, help='Path to the new kubeconfig file')
    parser.add_argument('--vault-addr', required=True, help='Vault server address')
    parser.add_argument('--vault-token', required=True, help='Vault token')
    parser.add_argument('--host-address', help='Host address to replace 127.0.0.1 with')
    
    args = parser.parse_args()
    
    print(f"Starting kubeconfig update for cluster: {args.cluster_name}")
    print(f"Using kubeconfig file: {args.kubeconfig_file}")
    print(f"Vault address: {args.vault_addr}")
    
    # Create Vault client
    client = get_vault_client(args.vault_addr, args.vault_token)
    if not client:
        print("Failed to create Vault client. Exiting.")
        sys.exit(1)
    
    # Read the new kubeconfig
    try:
        with open(args.kubeconfig_file, 'r') as f:
            new_kubeconfig = f.read()
            
            # Replace localhost with the host address if provided
            if args.host_address:
                print(f"Replacing 127.0.0.1/localhost with {args.host_address}")
                new_kubeconfig = new_kubeconfig.replace('127.0.0.1', args.host_address)
                new_kubeconfig = new_kubeconfig.replace('localhost', args.host_address)
    except Exception as e:
        print(f"Error reading kubeconfig file: {e}")
        sys.exit(1)
    
    # Get existing kubeconfig from Vault
    existing_kubeconfig = get_existing_kubeconfig(client)
    
    # Merge kubeconfigs
    merged_kubeconfig = merge_kubeconfig(existing_kubeconfig, new_kubeconfig, args.cluster_name)
    
    # Update Vault with merged kubeconfig
    if update_vault_kubeconfig(client, merged_kubeconfig):
        # Also update the cluster-secret-store
        update_cluster_secret_store(client, merged_kubeconfig)
        print("Successfully updated kubeconfig in Vault")
    else:
        print("Failed to update kubeconfig in Vault")
        sys.exit(1)


if __name__ == "__main__":
    main()