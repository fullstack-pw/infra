# Secret Rotation Process

This document outlines the process for rotating secrets in our infrastructure. Since all secrets are stored encrypted in Git, the rotation process needs to update both the encrypted files and the actual secrets in our running systems.

## Regular Secret Rotation

For regular secret rotation (e.g., API keys, passwords):

1. **Update the encrypted secret:**
   ```bash
   # Edit the secret file
   bash edit_secret.sh secrets/dev/vault/cluster-secret-store/secrets/API_KEY.yaml
   
   # Or create a new one if replacing an old one
   bash new_secret.sh API_KEY "new-api-key-value" dev vault/cluster-secret-store/secrets
   ```

2. **Commit the updated encrypted secret:**
   ```bash
   git add secrets/dev/vault/cluster-secret-store/secrets/API_KEY.yaml
   git commit -m "Rotate API_KEY for dev environment"
   git push
   ```

3. **Apply the change to Vault:**
   This will be handled by the bootstrap script in Phase 3, but for now:
   ```bash
   # Decrypt the secret
   DECRYPTED=$(sops --decrypt secrets/dev/vault/cluster-secret-store/secrets/API_KEY.yaml)
   
   # Extract just the value
   NEW_VALUE=$(echo "$DECRYPTED" | yq '.vault.kv.cluster-secret-store.secrets.API_KEY')
   
   # Update Vault (using vault CLI)
   vault kv put kv/cluster-secret-store/secrets API_KEY="$NEW_VALUE"
   ```

4. **Verify the rotation:**
   ```bash
   # Check the value in Vault
   vault kv get kv/cluster-secret-store/secrets
   ```

## Emergency Secret Rotation

For emergency rotations (e.g., a secret has been compromised):

1. **Immediately generate a new secret:**
   ```bash
   # Generate a new random secret
   NEW_SECRET=$(openssl rand -base64 32)
   
   # Create/update the encrypted file
   bash new_secret.sh COMPROMISED_SECRET "$NEW_SECRET" all vault/cluster-secret-store/secrets
   ```

2. **Apply the change to Vault immediately:**
   ```bash
   vault kv put kv/cluster-secret-store/secrets COMPROMISED_SECRET="$NEW_SECRET"
   ```

3. **Commit the updated encrypted secret:**
   ```bash
   git add secrets/all/vault/cluster-secret-store/secrets/COMPROMISED_SECRET.yaml
   git commit -m "Emergency rotation of COMPROMISED_SECRET"
   git push
   ```

4. **Update all affected applications:**
   - For applications using External Secrets, they should automatically update
   - For other applications, initiate any necessary restarts or redeployments

5. **Document the incident:**
   - Record when and why the secret was rotated
   - Document any additional steps taken to address the compromise

## Key (Age/SOPS) Rotation

For rotating the encryption keys themselves:

1. **Generate a new age key:**
   ```bash
   mkdir -p ~/.sops/keys-new
   age-keygen -o ~/.sops/keys-new/sops-key.txt
   ```

2. **Extract the public key:**
   ```bash
   NEW_PUBLIC_KEY=$(grep "public key:" ~/.sops/keys-new/sops-key.txt | cut -d' ' -f4)
   ```

3. **Update .sops.yaml to include both keys:**
   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age:
         - age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx # Old key
         - age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy # New key
   ```

4. **Re-encrypt all secrets with both keys:**
   ```bash
   # Set environment variable to use new key for encryption
   export SOPS_AGE_KEY_FILE=~/.sops/keys-new/sops-key.txt
   
   # Re-encrypt each file
   find secrets -type f -name "*.yaml" | while read -r file; do
     # Decrypt with old key
     OLD_SOPS_AGE_KEY_FILE=~/.sops/keys/sops-key.txt
     DECRYPTED=$(SOPS_AGE_KEY_FILE=$OLD_SOPS_AGE_KEY_FILE sops --decrypt "$file")
     
     # Create a temporary file
     echo "$DECRYPTED" > "$file.tmp"
     
     # Re-encrypt with new key
     sops --encrypt --in-place "$file.tmp"
     
     # Replace original file
     mv "$file.tmp" "$file"
   done
   ```

5. **Commit the updated files:**
   ```bash
   git add secrets/ .sops.yaml
   git commit -m "Rotate SOPS age encryption keys"
   git push
   ```

6. **Update the key in secure storage:**
   - Update the key in your password manager or secure storage
   - Share the new key with team members who need access
   - Once everyone has the new key, you can remove the old key from .sops.yaml

7. **Verify the new key works:**
   ```bash
   # Test decryption with new key
   export SOPS_AGE_KEY_FILE=~/.sops/keys-new/sops-key.txt
   bash view_secret.sh secrets/dev/vault/cluster-secret-store/secrets/TEST.yaml
   ```