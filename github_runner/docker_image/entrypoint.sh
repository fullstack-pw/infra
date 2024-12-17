#!/bin/bash

set -e

# Check for required environment variables
if [ -z "${GITHUB_URL}" ] || [ -z "${GITHUB_PAT}" ]; then
    echo "Error: GITHUB_URL and GITHUB_PAT environment variables are required."
    exit 1
fi

# Fetch a new runner token from GitHub
echo "Fetching new runner token from GitHub..."
RUNNER_TOKEN=$(curl -s -X POST -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github.v3+json" \
  "${GITHUB_API_URL}/actions/runners/registration-token" | jq -r .token)

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Failed to fetch runner token."
    exit 1
fi

# Configure the runner
echo "Configuring the GitHub Actions runner..."
./config.sh --url "${GITHUB_URL}" --token "${RUNNER_TOKEN}" --unattended --replace

# Start the runner
echo "Starting the GitHub Actions runner..."
exec ./run.sh
