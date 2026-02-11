#!/bin/bash
for file in "$@"; do
  if ! grep -q "^sops:" "$file" 2>/dev/null; then
    echo "ERROR: Unencrypted secret file: $file"
    echo "Encrypt with: sops --encrypt --in-place $file"
    exit 1
  fi
done
