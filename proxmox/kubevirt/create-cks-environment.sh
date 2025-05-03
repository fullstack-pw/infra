#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

export SESSION_ID=${1:-$(date +%s | sha256sum | base64 | head -c 6 | tr '[:upper:]' '[:lower:]')}
export SESSION_NAMESPACE="user-session-${SESSION_ID}"

# Configuration parameters
export K8S_VERSION="1.33.0"
export CPU_CORES="2"
export MEMORY="2Gi"
export STORAGE_SIZE="20Gi"
export STORAGE_CLASS="local-path"
export CNI_PLUGIN="cilium"
export POD_CIDR="10.0.0.0/8"
export IMAGE_URL="https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"

# Control plane configuration
export CONTROL_PLANE_VM_NAME="cks-control-plane-${SESSION_ID}"
export CONTROL_PLANE_HOST="${CONTROL_PLANE_VM_NAME}"
export CONTROL_PLANE_FILE="templates/control-plane-template.yaml"
export CONTROL_PLANE_CONFIG_SECRET_FILE="templates/control-plane-cloud-config-secret.yaml"
export CONTROL_PLANE_USERDATA=$(envsubst < templates/control-plane-cloud-config.yaml | base64 -w0)

# Check prerequisites
if ! kubectl api-resources | grep -q virtualmachine; then
  echo -e "${RED}KubeVirt doesn't appear to be installed. Please install KubeVirt first.${NC}"
  exit 1
fi

if ! kubectl api-resources | grep -q datavolume; then
  echo -e "${RED}Containerized Data Importer (CDI) doesn't appear to be installed. Please install CDI first.${NC}"
  exit 1
fi

# Create namespace
kubectl create namespace ${SESSION_NAMESPACE}




echo -e "${YELLOW}Creating control plane VM...${NC}"
# Create control plane VM
envsubst < ${CONTROL_PLANE_CONFIG_SECRET_FILE} | kubectl apply -f -
envsubst < ${CONTROL_PLANE_FILE} | kubectl apply -f -
sleep 5

# Wait for control plane DataVolume to be ready
echo -e "${YELLOW}Waiting for control plane DataVolume to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${SESSION_NAMESPACE} datavolume/${CONTROL_PLANE_VM_NAME}-rootdisk --timeout=10m

# Wait for control plane VM to be ready
echo -e "${YELLOW}Waiting for control plane VM to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${SESSION_NAMESPACE} virtualmachine/${CONTROL_PLANE_VM_NAME} --timeout=15m
echo -e "${GREEN}Control plane VM created successfully.${NC}"

export CONTROL_PLANE_ENDPOINT=$(kubectl get vmi -n ${SESSION_NAMESPACE} -o custom-columns='NAME:.metadata.name,IP:.status.interfaces[0].ipAddress' --no-headers | grep ${CONTROL_PLANE_VM_NAME} | awk '{print $2}'|sed 's/\./\-/g').${SESSION_NAMESPACE}.pod.cluster.local
export CONTROL_PLANE_IP=$(kubectl get vmi -n ${SESSION_NAMESPACE} -o custom-columns='NAME:.metadata.name,IP:.status.interfaces[0].ipAddress' --no-headers | grep ${CONTROL_PLANE_VM_NAME} | awk '{print $2}')

# Wait for the control plane to initialize (after waiting for VM to be ready)
echo -e "${YELLOW}Waiting for Kubernetes control plane to initialize...${NC}"
sleep 30
ATTEMPTS=0
MAX_ATTEMPTS=30
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  GET_JOIN=$(virtctl ssh vmi/cks-control-plane-$SESSION_ID -n user-session-$SESSION_ID -l suporte --command='cat /etc/kubeadm-join-command' --local-ssh-opts="-o StrictHostKeyChecking=no"|sed "s/\b(?:\d{1,3}\.){3}\d{1,3}\b/cks-control-plane-$SESSION_ID/g")
  
  if [ ! -z "$GET_JOIN" ]; then
    echo $GET_JOIN
    export JOIN_COMMAND=$(echo $GET_JOIN)
    break
  fi
  
  echo -e "${YELLOW}Attempt $ATTEMPTS: Waiting for control plane to generate join command...${NC}"
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Failed to get join command after $MAX_ATTEMPTS attempts.${NC}"
  echo -e "${YELLOW}You may need to manually join the worker node to the cluster.${NC}"
  exit
fi


# Worker node configuration
export WORKER_VM_NAME="cks-worker-node-${SESSION_ID}"
export WORKER_FILE="templates/worker-node-template.yaml"
export WORKER_CONFIG_SECRET_FILE="templates/worker-node-cloud-config-secret.yaml"
export WORKER_USERDATA=$(envsubst < templates/worker-node-cloud-config.yaml | base64 -w0)

echo -e "${YELLOW}Creating worker node VM...${NC}"
# Create worker node VM
envsubst < ${WORKER_CONFIG_SECRET_FILE} | kubectl apply -f -
envsubst < ${WORKER_FILE} | kubectl apply -f -
sleep 5

# Wait for worker node DataVolume to be ready
echo -e "${YELLOW}Waiting for worker node DataVolume to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${SESSION_NAMESPACE} datavolume/${WORKER_VM_NAME}-rootdisk --timeout=10m

# Wait for worker node VM to be ready
echo -e "${YELLOW}Waiting for worker node VM to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${SESSION_NAMESPACE} virtualmachine/${WORKER_VM_NAME} --timeout=15m

echo -e "${GREEN}Worker node VM created successfully.${NC}"




# Print VM info
VM_IP=$(kubectl get vmi -n ${SESSION_NAMESPACE} -o custom-columns='NAME:.metadata.name,IP:.status.interfaces[0].ipAddress' --no-headers | grep ${CONTROL_PLANE_VM_NAME} | awk '{print $2}')

echo -e "${GREEN}===========================${NC}"
echo -e "${GREEN}CKS Environment Created!${NC}"
echo -e "${GREEN}===========================${NC}"
echo -e "Namespace: ${SESSION_NAMESPACE}"
echo -e "Control Plane VM: ${CONTROL_PLANE_VM_NAME}"
echo -e "Worker Node VM: ${WORKER_VM_NAME}"
echo -e "${YELLOW}Use the following command to get VM status:${NC}"
echo -e "kubectl get virtualmachine -n ${SESSION_NAMESPACE}"
echo -e "${YELLOW}Use the following command to get VM IP addresses:${NC}"
echo -e "kubectl get vmi -n ${SESSION_NAMESPACE} -o custom-columns=NAME:.metadata.name,IP:.status.interfaces[0].ipAddress"
echo -e "${YELLOW}Use virtctl to access the VM console:${NC}"
echo -e "virtctl console ${CONTROL_PLANE_VM_NAME} -n ${SESSION_NAMESPACE}"
echo -e ""
echo -e "${YELLOW}It may take a few minutes for Kubernetes components to initialize.${NC}"
echo -e "${YELLOW}You can check the status with:${NC}"
echo -e "virtctl console ${CONTROL_PLANE_VM_NAME} -n ${SESSION_NAMESPACE} -- kubectl get nodes"