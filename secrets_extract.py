#!/usr/bin/env python3
"""
Script to extract secrets from HashiCorp Vault and save them as YAML files for SOPS encryption.
This is a one-time extraction to initialize your Git-stored encrypted secrets.
"""

import os
import sys
import json
import yaml
import hvac
import argparse
from pathlib import Path

def parse_args():
    parser = argparse.ArgumentParser(description='Extract secrets from Vault to YAML files')
    parser.add_argument('--vault-addr', default=os.environ.get('VAULT_ADDR', 'https://vault.fullstack.pw'),
                      help='Vault server address')
    parser.add_argument('--vault-token', default=os.environ.get('VAULT_TOKEN'),
                      help='Vault token (or set VAULT_TOKEN env var)')
    parser.add_argument('--output-dir', default='secrets',
                      help='Base directory for output files')
    parser.add_argument('--environment', default='all',
                      help='Environment to extract (dev, stg, prod, all)')
    parser.add_argument('--dryrun', action='store_true',
                      help='Print paths but do not extract secrets')
    return parser.parse_args()

def setup_vault_client(vault_addr, vault_token):
    client = hvac.Client(url=vault_addr, token=vault_token)
    if not client.is_authenticated():
        print(f"Failed to authenticate to Vault at {vault_addr}")
        sys.exit(1)
    print(f"Successfully authenticated to Vault at {vault_addr}")
    return client

def get_secrets_paths(client, mount_point='kv'):
    """Get all secret paths in the given mount point"""
    try:
        # List all paths at the root of the KV store
        paths = []
        # This is a recursive function to get all paths
        def list_recursive(path=""):
            try:
                # For KV v2, use the metadata endpoint
                list_response = client.secrets.kv.v2.list_secrets(
                    path=path,
                    mount_point=mount_point
                )
                keys = list_response.get('data', {}).get('keys', [])
                for key in keys:
                    # If key ends with /, it's a directory
                    if key.endswith('/'):
                        list_recursive(f"{path}{key}" if path else key)
                    else:
                        full_path = f"{path}{key}" if path else key
                        paths.append(full_path)
            except Exception as e:
                # If we get an error, this might be a leaf node
                pass
        
        list_recursive()
        return paths
    except Exception as e:
        print(f"Error listing secret paths: {e}")
        return []

def get_secret(client, path, mount_point='kv'):
    """Get a secret from Vault at the given path"""
    try:
        # For KV v2
        secret = client.secrets.kv.v2.read_secret_version(
            path=path,
            mount_point=mount_point
        )
        return secret.get('data', {}).get('data', {})
    except Exception as e:
        print(f"Error reading secret at {path}: {e}")
        return {}

def save_to_yaml(data, output_file, environment):
    """Save structured data to a YAML file"""
    # Ensure parent directories exist
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Parse the path to determine the structure
    parts = output_file.replace('.yaml', '').split('/')
    path_parts = parts[2:]  # Skip 'secrets/dev' prefix
    
    # Create nested structure
    nested_data = {}
    current = nested_data
    
    # Add standard structure
    # Example: 'cluster-secret-store/secrets/KUBECONFIG' 
    # would become vault: { kv: { cluster-secret-store: { secrets: { KUBECONFIG: value } } } }
    
    # Start with vault.kv
    current['vault'] = {'kv': {}}
    current = current['vault']['kv']
    
    # # Handle special cases like individual keys in cluster-secret-store/secrets
    # if len(path_parts) >= 2 and path_parts[0] == 'cluster-secret-store' and path_parts[1] == 'secrets':
    #     # Check if we're dealing with a specific key or the whole secrets map
    #     if len(path_parts) == 3:
    #         # Individual key like KUBECONFIG
    #         key_name = path_parts[2]
    #         current['cluster-secret-store'] = {'secrets': {key_name: data[key_name]}}
    #     else:
    #         # The whole secrets map
    #         current['cluster-secret-store'] = {'secrets': data}
    # else:
        # Standard nested path
    for i, part in enumerate(path_parts):
        if i == len(path_parts) - 1:
            # Last part, assign the data
            current[part] = data
        else:
            # Intermediate path part
            current[part] = {}
            current = current[part]
    
    # Write to file
    with open(output_file, 'w') as f:
        yaml.dump(nested_data, f, default_flow_style=False)
    
    print(f"Saved secrets to {output_file}")

def determine_environment(path):
    """Try to determine which environment a secret belongs to"""
    # Add your own logic here based on your naming conventions
    if '/dev/' in path.lower():
        return 'dev'
    elif '/stg/' in path.lower() or 'staging' in path.lower():
        return 'stg'
    elif '/prod/' in path.lower() or 'production' in path.lower():
        return 'prod'
    else:
        # Default to common (shared across environments)
        return 'common'

def main():
    args = parse_args()
    
    if not args.vault_token:
        print("Error: No Vault token provided. Set VAULT_TOKEN env var or use --vault-token")
        sys.exit(1)
    
    client = setup_vault_client(args.vault_addr, args.vault_token)
    
    # Get all secret paths
    print("Listing secret paths from Vault...")
    paths = get_secrets_paths(client)
    
    if not paths:
        print("No secrets found or error occurred")
        sys.exit(1)
    
    print(f"Found {len(paths)} secret paths")
    
    # Process each path
    for path in paths:
        # Determine which environment this secret belongs to
        env = determine_environment(path)
        
        # Skip if not requested environment
        if args.environment != 'all' and env != args.environment:
            continue
        
        print(f"Processing {path} (environment: {env})")
        
        if args.dryrun:
            print(f"  Would extract to {args.output_dir}/{env}/{path}.yaml")
            continue
        
        # Get the secret
        secret_data = get_secret(client, path)
        if not secret_data:
            print(f"  No data found or error occurred for {path}")
            continue
        
        # Save to YAML
        output_file = f"{args.output_dir}/{env}/{path}.yaml"
        save_to_yaml(secret_data, output_file, env)
    
    print("Done!")

if __name__ == "__main__":
    main()