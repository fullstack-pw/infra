# Extracting and Encrypting Vault Secrets

This document explains how to extract secrets from your existing Vault instance and store them encrypted in Git.

## Prerequisites

1. Access to your Vault instance with a token that has read permissions
2. SOPS and age installed (see main README)
3. Python 3.6+ with pip

## Setup

1. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set environment variables:
   ```bash
   export VAULT_ADDR="https://vault.fullstack.pw"  # Your Vault address
   export VAULT_TOKEN="your-vault-token"
   export SOPS_AGE_KEY_FILE=~/.sops/keys/sops-key.txt
   ```

## Extraction Process

### 1. Extract secrets from Vault

First, run the extraction script to pull secrets from Vault:

```bash
# Preview what would be extracted (dry run)
python3 extract_vault_secrets.py --dryrun

# Extract secrets for all environments
python3 extract_vault_secrets.py

# Extract secrets for a specific environment
python3 extract_vault_secrets.py --environment dev
```

This will create YAML files in the `secrets/` directory that match your Vault structure.

### 2. Encrypt all extracted secrets

Next, encrypt all the extracted secrets:

```bash
bash encrypt_secrets.sh
```

### 3. Verify the encrypted secrets

You can view the encrypted secrets to verify they were properly encrypted:

```bash
# View an encrypted file
cat secrets/dev/vault/cluster-secret-store/secrets/GITHUB_PAT.yaml

# Decrypt and view a secret
bash view_secret.sh secrets/dev/vault/cluster-secret-store/secrets/GITHUB_PAT.yaml
```

### 4. Commit to Git

Once you've verified the secrets are properly encrypted, commit them to Git:

```bash
git add secrets/
git commit -m "Add encrypted secrets from Vault"
git push
```

## Working with Secrets

### View a secret
```bash
bash view_secret.sh secrets/dev/vault/cluster-secret-store/secrets/GITHUB_PAT.yaml
```

### Edit a secret
```bash
bash edit_secret.sh secrets/dev/vault/cluster-secret-store/secrets/GITHUB_PAT.yaml
```

### Create a new secret
```bash
bash new_secret.sh NEW_API_KEY "your-secret-value" dev vault/cluster-secret-store/secrets
```

## Security Notes

1. Never commit the extraction script output before encrypting it
2. Keep your VAULT_TOKEN secure and do not commit it
3. Store the age private key securely and separately from this repository