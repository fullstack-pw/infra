#!/bin/bash
# Script to test KillerKoda CKS VM templates

set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Generate test session ID
SESSION_ID=$(date +%s | sha256sum | base64 | head -c 6)
NAMESPACE="test-session-${SESSION_ID}"
CP_VM_NAME="cks-control-plane-test"
WORKER_VM_NAME="cks-worker-node-test"

echo -e "${YELLOW}Testing KillerKoda CKS VM Templates (K8s v1.33.0)...${NC}"
echo -e "${YELLOW}Session ID: ${SESSION_ID}${NC}"

# Create test namespace
echo -e "${YELLOW}Creating test namespace: ${NAMESPACE}...${NC}"
kubectl create namespace ${NAMESPACE}

# Export environment variables for templates
export VM_NAMESPACE=${NAMESPACE}
export SESSION_ID=${SESSION_ID}
export K8S_VERSION="1.33.0"
export CPU_CORES="2"
export MEMORY="2Gi"
export STORAGE_SIZE="20Gi"
export STORAGE_CLASS="local-path"
export CNI_PLUGIN="flannel"
export POD_CIDR="10.244.0.0/16"
export CONTROL_PLANE_HOST=${CP_VM_NAME}

# Create control plane VM
echo -e "${YELLOW}Deploying control plane VM...${NC}"
export VM_NAME=${CP_VM_NAME}

# Debug: Print environment variables
echo -e "${YELLOW}Environment variables for control plane VM:${NC}"
echo -e "VM_NAME=$VM_NAME"
echo -e "VM_NAMESPACE=$VM_NAMESPACE"
echo -e "SESSION_ID=$SESSION_ID"

cat ./templates/control-plane-template.yaml | envsubst | kubectl apply -f -
echo -e "${GREEN}Control plane VM deployed.${NC}"

# Wait for control plane VM DataVolume to be ready
echo -e "${YELLOW}Waiting for control plane VM DataVolume to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${NAMESPACE} datavolume/${CP_VM_NAME}-rootdisk --timeout=10m

# Create worker node VM
echo -e "${YELLOW}Deploying worker node VM...${NC}"
export VM_NAME=${WORKER_VM_NAME}

# Debug: Print environment variables for worker
echo -e "${YELLOW}Environment variables for worker node VM:${NC}"
echo -e "VM_NAME=$VM_NAME"
echo -e "VM_NAMESPACE=$VM_NAMESPACE"
echo -e "SESSION_ID=$SESSION_ID"
echo -e "CONTROL_PLANE_HOST=$CONTROL_PLANE_HOST"

cat ./templates/worker-node-template.yaml | envsubst | kubectl apply -f -
echo -e "${GREEN}Worker node VM deployed.${NC}"

# Wait for worker node VM DataVolume to be ready
echo -e "${YELLOW}Waiting for worker node VM DataVolume to be ready...${NC}"
kubectl wait --for=condition=Ready -n ${NAMESPACE} datavolume/${WORKER_VM_NAME}-rootdisk --timeout=10m

# Wait for VMs to be running
echo -e "${YELLOW}Waiting for VMs to be running...${NC}"
kubectl wait --for=condition=Ready -n ${NAMESPACE} virtualmachine/${CP_VM_NAME} --timeout=15m
kubectl wait --for=condition=Ready -n ${NAMESPACE} virtualmachine/${WORKER_VM_NAME} --timeout=15m

# Check for virtctl
echo -e "${YELLOW}Checking for virtctl...${NC}"
if ! command -v virtctl &> /dev/null; then
  echo -e "${RED}virtctl not found. Please install virtctl to continue testing.${NC}"
  echo -e "${YELLOW}You can install it using:${NC}"
  echo -e "curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/v0.58.0/virtctl-v0.58.0-linux-amd64"
  echo -e "chmod +x virtctl"
  echo -e "sudo mv virtctl /usr/local/bin"
  exit 1
fi

# Wait for control plane to initialize (this may take some time)
echo -e "${YELLOW}Waiting for Kubernetes control plane to initialize...${NC}"
ATTEMPTS=0
MAX_ATTEMPTS=60

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get nodes &> /dev/null; then
    break
  fi
  echo -n "."
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Control plane initialization timed out.${NC}"
  exit 1
fi

echo -e "\n${GREEN}Control plane initialized.${NC}"

# Check node status
echo -e "${YELLOW}Checking node status...${NC}"
NODES_OUTPUT=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get nodes -o wide)
echo "$NODES_OUTPUT"

# Check if worker node joined
if echo "$NODES_OUTPUT" | grep -q "${WORKER_VM_NAME}"; then
  echo -e "${GREEN}Worker node joined the cluster successfully.${NC}"
else
  echo -e "${RED}Worker node did not join the cluster.${NC}"
  exit 1
fi

# Test pod networking
echo -e "${YELLOW}Testing pod networking...${NC}"
virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl run test-pod --image=busybox -- sleep 3600 &> /dev/null

# Wait for pod to be running
echo -e "${YELLOW}Waiting for test pod to be running...${NC}"
ATTEMPTS=0
MAX_ATTEMPTS=30

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get pod test-pod | grep -q Running; then
    break
  fi
  echo -n "."
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 5
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Test pod did not start.${NC}"
  exit 1
fi

echo -e "\n${GREEN}Test pod is running.${NC}"

# Create another pod on worker node
echo -e "${YELLOW}Creating test pod on worker node...${NC}"
cat <<EOT | virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-worker
spec:
  nodeName: ${WORKER_VM_NAME}
  containers:
  - name: busybox
    image: busybox
    command:
    - sleep
    - "3600"
EOT

# Wait for worker pod to be running
echo -e "${YELLOW}Waiting for worker test pod to be running...${NC}"
ATTEMPTS=0
MAX_ATTEMPTS=30

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  if virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get pod test-pod-worker | grep -q Running; then
    break
  fi
  echo -n "."
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 5
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Worker test pod did not start.${NC}"
  exit 1
fi

echo -e "\n${GREEN}Worker test pod is running.${NC}"

# Test communication between pods
echo -e "${YELLOW}Testing pod communication...${NC}"
FIRST_POD_IP=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get pod test-pod -o jsonpath='{.status.podIP}')
echo -e "First pod IP: ${FIRST_POD_IP}"

PING_RESULT=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl exec test-pod-worker -- ping -c 3 ${FIRST_POD_IP})
echo "$PING_RESULT"

if echo "$PING_RESULT" | grep -q "3 packets transmitted, 3 received"; then
  echo -e "${GREEN}Pod networking test successful!${NC}"
else
  echo -e "${RED}Pod networking test failed.${NC}"
  exit 1
fi

# Test DNS resolution
echo -e "${YELLOW}Testing DNS resolution...${NC}"
DNS_RESULT=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl exec test-pod -- nslookup kubernetes.default)
echo "$DNS_RESULT"

if echo "$DNS_RESULT" | grep -q "kubernetes.default.svc.cluster.local"; then
  echo -e "${GREEN}DNS resolution test successful!${NC}"
else
  echo -e "${RED}DNS resolution test failed.${NC}"
  exit 1
fi

# Test control plane components
echo -e "${YELLOW}Checking control plane components...${NC}"
COMPONENTS=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl get pods -n kube-system)
echo "$COMPONENTS"

# Check Kubernetes version
echo -e "${YELLOW}Verifying Kubernetes version...${NC}"
K8S_VERSION=$(virtctl console ${CP_VM_NAME} -n ${NAMESPACE} -- kubectl version --output=json | grep -o '"serverVersion":.*"major":"[0-9]*","minor":"[0-9]*"')
echo "$K8S_VERSION"

if echo "$K8S_VERSION" | grep -q '"minor":"33"'; then
  echo -e "${GREEN}Kubernetes version verified (v1.33.0)!${NC}"
else
  echo -e "${RED}Kubernetes version verification failed.${NC}"
  exit 1
fi

# Clean up test resources
echo -e "${YELLOW}Tests completed successfully. Cleaning up...${NC}"
kubectl delete namespace ${NAMESPACE} --wait=false

echo -e "${GREEN}===========================${NC}"
echo -e "${GREEN}All tests passed successfully!${NC}"
echo -e "${GREEN}===========================${NC}"
echo -e "VM templates are ready for use in the KillerKoda-Local environment."
echo -e "You can now proceed with configuring the next components of the project."

exit 0