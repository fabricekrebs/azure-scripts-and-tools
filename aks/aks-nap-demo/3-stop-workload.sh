#!/bin/bash

# Simple AKS NAP Demo - Stop Workload
# Removes demo workloads and monitors NAP automatic node removal

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 AKS NAP Demo - Stop Workload${NC}"
echo "==============================="
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl is not configured or cluster is not accessible${NC}"
    echo "Please run ./1-deploy-infrastructure.sh first"
    exit 1
fi

echo -e "${GREEN}✅ Connected to cluster${NC}"
echo ""

# Show current cluster state before cleanup
echo -e "${BLUE}📊 Current Cluster State Before Cleanup:${NC}"
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "NodeClaims:"
kubectl get nodeclaim 2>/dev/null || echo "No NodeClaims found"
echo ""
echo "Demo Workloads:"
kubectl get pods -n nap-demo 2>/dev/null || echo "No demo workloads found"
echo ""

# Remove demo workloads
echo -e "${GREEN}🗑️  Removing demo workloads...${NC}"
if kubectl get namespace nap-demo &> /dev/null; then
    kubectl delete namespace nap-demo --ignore-not-found=true
    echo -e "${GREEN}✅ Demo namespace and workloads removed${NC}"
else
    echo -e "${YELLOW}ℹ️  No demo workloads found to remove${NC}"
fi

echo ""
echo -e "${YELLOW}⏳ Waiting 30 seconds for scheduler to react...${NC}"
sleep 30

echo ""
echo -e "${BLUE}📊 Cluster State After Workload Removal:${NC}"
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "NodeClaims:"
kubectl get nodeclaim 2>/dev/null || echo "No NodeClaims found"
echo ""

echo -e "${YELLOW}💡 NAP Node Cleanup Process:${NC}"
echo "  - NAP typically waits 30-60 seconds before marking nodes for removal"
echo "  - Nodes are gracefully drained before termination"
echo "  - Total cleanup time: 2-5 minutes"
echo ""
echo -e "${YELLOW}💡 Monitor NAP cleanup with:${NC}"
echo "  watch 'kubectl get nodes && echo && kubectl get nodeclaim'"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  - Wait 5 minutes to see NAP automatically remove unused nodes"
echo "  - Run: ./2-start-workload.sh to test NAP scaling again"
echo "  - Run: ./4-cleanup.sh to remove all Azure resources"