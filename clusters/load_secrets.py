#!/usr/bin/env python3
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
    try:
        result = subprocess.run(
            ['sops', '--decrypt', file_path],
            capture_output=True,
            text=True,
            check=True
        )
        
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
    if result is None:
        result = {}
    
    if isinstance(data, dict):
        for key, value in data["vault"].items():
            if isinstance(value, dict):
                process_path_data(key, value, "", result)
            else:
                result[key] = {key: value}
    
    return result

def process_path_data(path_segment, path_data, current_path, result):
    path = f"{current_path}/{path_segment}" if current_path else path_segment
    
    if isinstance(path_data, dict):
        if not any(isinstance(v, dict) for v in path_data.values()):
            result[path] = path_data
        else:
            for key, value in path_data.items():
                process_path_data(key, value, path, result)

def process_secrets(env_dir, output_file):
    all_secrets = {}
    
    for root, _, files in os.walk(env_dir):
        for file in files:
            if file.endswith(('.yaml', '.yml', '.json')):
                file_path = os.path.join(root, file)
                print(f"Processing {file_path}...")
                
                decrypted_data = decrypt_file(file_path)
                if not decrypted_data:
                    continue
                
                processed = flatten_vault_structure(decrypted_data)
                
                for path, secrets in processed.items():
                    if path not in all_secrets:
                        all_secrets[path] = {}
                    all_secrets[path].update(secrets)
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w') as f:
        json.dump(all_secrets, f, indent=2)
    
    print(f"Secrets processed and saved to {output_file}")
    return all_secrets

def main():
    args = parse_args()
    
    if 'SOPS_AGE_KEY_FILE' not in os.environ:
        print("Error: SOPS_AGE_KEY_FILE environment variable is not set")
        sys.exit(1)
    
    os.makedirs('tmp', exist_ok=True)
    
    if args.environment == 'all':
        all_secrets = {}
        
        for env in ['dev', 'stg', 'prod', 'common']:
            env_dir = os.path.join(args.secrets_dir, env)
            if os.path.isdir(env_dir):
                print(f"Processing {env} environment...")
                env_secrets = process_secrets(env_dir, f"tmp/{env}_secrets.json")
                all_secrets.update(env_secrets)
        
        with open(args.output, 'w') as f:
            json.dump(all_secrets, f, indent=2)
            
        print(f"All environments processed and combined into {args.output}")
    else:
        env_dir = os.path.join(args.secrets_dir, args.environment)
        if not os.path.isdir(env_dir):
            print(f"Error: Environment directory not found: {env_dir}")
            sys.exit(1)
        
        process_secrets(env_dir, args.output)

if __name__ == "__main__":
    main()