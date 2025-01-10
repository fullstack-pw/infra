#!/bin/bash
set -e

IMAGE_NAME="registry.fullstack.pw/github-runner:latest"
DOCKERFILE_PATH="./docker/runner"

# Build the image using nerdctl
nerdctl build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .

# Push the image to the registry
nerdctl push "$IMAGE_NAME"

# Output the image name for Terraform
echo "{\"image_name\": \"$IMAGE_NAME\"}"
