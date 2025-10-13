#!/bin/bash

# Simple AKS NAP Demo - Start Workload
# Deploys resource-intensive workloads that will trigger NAP to provision new nodes

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 AKS NAP Demo - Start Workload${NC}"
echo "================================"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl is not configured or cluster is not accessible${NC}"
    echo "Please run ./1-deploy-infrastructure.sh first"
    exit 1
fi

echo -e "${GREEN}✅ Connected to cluster${NC}"
echo ""

# Show initial cluster state
echo -e "${BLUE}📊 Initial Cluster State:${NC}"
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "NodePools:"
kubectl get nodepool
echo ""
echo "NodeClaims:"
kubectl get nodeclaim 2>/dev/null || echo "No NodeClaims found yet (normal)"
echo ""

# Deploy resource-intensive workloads
echo -e "${GREEN}🎯 Deploying resource-intensive workloads to trigger NAP...${NC}"
echo ""

# Create namespace
kubectl create namespace nap-demo --dry-run=client -o yaml | kubectl apply -f -

# Deploy CPU-intensive workload
echo -e "${BLUE}📋 Deploying CPU-intensive workload...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-intensive-demo
  namespace: nap-demo
  labels:
    app: cpu-intensive-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cpu-intensive-demo
  template:
    metadata:
      labels:
        app: cpu-intensive-demo
    spec:
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2", "--timeout", "3600s"]
        resources:
          requests:
            cpu: "2000m"
            memory: "2Gi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-intensive-demo
  namespace: nap-demo
  labels:
    app: memory-intensive-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: memory-intensive-demo
  template:
    metadata:
      labels:
        app: memory-intensive-demo
    spec:
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "2", "--vm-bytes", "3G", "--timeout", "3600s"]
        resources:
          requests:
            cpu: "1000m"
            memory: "4Gi"
          limits:
            cpu: "1000m"
            memory: "4Gi"
EOF

echo ""
echo -e "${YELLOW}⏳ Waiting 30 seconds for workloads to be scheduled...${NC}"
sleep 30

echo ""
echo -e "${BLUE}📊 Workload Status:${NC}"
kubectl get pods -n nap-demo -o wide

echo ""
echo -e "${BLUE}🔍 Checking for new NodeClaims (NAP activity):${NC}"
kubectl get nodeclaim 2>/dev/null || echo "No NodeClaims visible yet - NAP may still be evaluating"

echo ""
echo -e "${BLUE}📊 Current Nodes:${NC}"
kubectl get nodes -o wide

echo ""
echo -e "${YELLOW}💡 Monitor NAP activity with:${NC}"
echo "  watch 'kubectl get nodes && echo && kubectl get nodeclaim && echo && kubectl get pods -n nap-demo'"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  - Wait 2-5 minutes for NAP to provision new nodes"
echo "  - Run: ./3-stop-workload.sh to remove workloads and see nodes scale down"