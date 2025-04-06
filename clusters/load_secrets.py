#!/usr/bin/env python3
"""
Script to decrypt SOPS-encrypted files and convert them to a format 
suitable for the Terraform Vault module's initial_secrets input.
"""

import os
import sys
import json
import yaml
import subprocess
import argparse
from pathlib import Path

def parse_args():
    parser = argparse.ArgumentParser(description='Load encrypted secrets for Vault bootstrap')
    parser.add_argument('--environment', default='all',
                       help='Environment to load (dev, stg, prod, all)')
    parser.add_argument('--secrets-dir', default='../secrets',
                       help='Base directory for secrets')
    parser.add_argument('--output', default='tmp/secrets.json',
                       help='Output file for processed secrets')
    return parser.parse_args()

def decrypt_file(file_path):
    """Decrypt a SOPS-encrypted file and return its contents as a Python object"""
    try:
        # Use subprocess to call SOPS
        result = subprocess.run(
            ['sops', '--decrypt', file_path],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the YAML output to a Python dict
        if file_path.endswith('.yaml') or file_path.endswith('.yml'):
            return yaml.safe_load(result.stdout)
        elif file_path.endswith('.json'):
            return json.loads(result.stdout)
        else:
            print(f"Unsupported file format: {file_path}")
            return None
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting {file_path}: {e.stderr}")
        return None
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return None

def flatten_vault_structure(data, current_path="", result=None):
    """
    Process the nested structure from YAML files into a format suitable for Vault.
    This converts from the vault: { kv: { path: { key: value } } } format 
    to the format expected by Terraform: { "path/key": { key: value } } format.
    """
    if result is None:
        result = {}
    
    if isinstance(data, dict):
        # # Handle the first level (vault)
        # if "vault" in data and "kv" in data["vault"]:
        #     # Process the kv section specifically to match Terraform format
        #     kv_data = data["vault"]["kv"]
            
        #     # Process each path and its secrets
        #     for path_segment, path_data in kv_data.items():
        #         if path_segment == "cluster-secret-store" and "secrets" in path_data:
        #             # Handle the special case for cluster-secret-store/secrets
        #             # Store it both as a single object and as individual secrets
                    
        #             # 1. Store as a single object called "cluster-secrets"
        #             result["cluster-secrets"] = path_data["secrets"]
                    
        #             # 2. Store each key as its own secret
        #             for secret_key, secret_value in path_data["secrets"].items():
        #                 secret_path = f"cluster-secret-store/secrets/{secret_key}"
        #                 result[secret_path] = {secret_key: secret_value}
        #         else:
        #             # Handle other paths
        #             process_path_data(path_segment, path_data, "", result)
        # elif "vault" in data:
        #     # Process vault data without kv structure
        for key, value in data["vault"].items():
            if isinstance(value, dict):
                process_path_data(key, value, "", result)
            else:
                # Handle direct key-value pairs under vault
                result[key] = {key: value}
    
    return result

def process_path_data(path_segment, path_data, current_path, result):
    """
    Helper function to process path data recursively.
    """
    # Build the current path
    path = f"{current_path}/{path_segment}" if current_path else path_segment
    
    if isinstance(path_data, dict):
        # Check if this is a leaf node with actual secrets
        if not any(isinstance(v, dict) for v in path_data.values()):
            # This is a leaf node with secrets
            result[path] = path_data
        else:
            # Continue recursion for nested paths
            for key, value in path_data.items():
                process_path_data(key, value, path, result)

def process_secrets(env_dir, output_file):
    """Process all secrets in the specified environment directory"""
    all_secrets = {}
    
    # Walk through all files in the environment directory
    for root, _, files in os.walk(env_dir):
        for file in files:
            if file.endswith(('.yaml', '.yml', '.json')):
                file_path = os.path.join(root, file)
                print(f"Processing {file_path}...")
                
                # Decrypt the file
                decrypted_data = decrypt_file(file_path)
                if not decrypted_data:
                    continue
                
                # Convert to the required structure
                processed = flatten_vault_structure(decrypted_data)
                
                # Merge into all_secrets
                for path, secrets in processed.items():
                    if path not in all_secrets:
                        all_secrets[path] = {}
                    all_secrets[path].update(secrets)
    
    # Create output directory if it doesn't exist
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Write the result to the output file
    with open(output_file, 'w') as f:
        json.dump(all_secrets, f, indent=2)
    
    print(f"Secrets processed and saved to {output_file}")
    return all_secrets

def main():
    args = parse_args()
    
    # Check if SOPS_AGE_KEY_FILE is set
    if 'SOPS_AGE_KEY_FILE' not in os.environ:
        print("Error: SOPS_AGE_KEY_FILE environment variable is not set")
        sys.exit(1)
    
    # Create tmp directory
    os.makedirs('tmp', exist_ok=True)
    
    if args.environment == 'all':
        # Process all environments
        all_secrets = {}
        
        # Check each environment directory
        for env in ['dev', 'stg', 'prod', 'common']:
            env_dir = os.path.join(args.secrets_dir, env)
            if os.path.isdir(env_dir):
                print(f"Processing {env} environment...")
                env_secrets = process_secrets(env_dir, f"tmp/{env}_secrets.json")
                all_secrets.update(env_secrets)
        
        # Write combined secrets
        with open(args.output, 'w') as f:
            json.dump(all_secrets, f, indent=2)
            
        print(f"All environments processed and combined into {args.output}")
    else:
        # Process a single environment
        env_dir = os.path.join(args.secrets_dir, args.environment)
        if not os.path.isdir(env_dir):
            print(f"Error: Environment directory not found: {env_dir}")
            sys.exit(1)
        
        process_secrets(env_dir, args.output)

if __name__ == "__main__":
    main()