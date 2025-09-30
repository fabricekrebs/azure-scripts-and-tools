#!/bin/bash

# Simple AKS NAP Demo - Deploy Infrastructure
# Deploys AKS cluster with NAP using Bicep templates

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
LOCATION="Italy North"
LOCATION_SHORT="italynorth"
RESOURCE_GROUP="rg-${LOCATION_SHORT}-aksnapdemo-01"
SSH_KEY_PATH="~/.ssh/id_rsa.pub"

echo -e "${GREEN}🚀 AKS NAP Demo - Deploy Infrastructure${NC}"
echo "===================================="
echo ""

# Check if logged into Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged into Azure. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Current subscription: $(az account show --query name -o tsv)${NC}"
echo -e "${BLUE}📋 Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${BLUE}📋 Location: $LOCATION${NC}"
echo ""

# Get SSH public key
SSH_KEY_PATH_EXPANDED=$(eval echo "$SSH_KEY_PATH")
if [ ! -f "$SSH_KEY_PATH_EXPANDED" ]; then
    echo -e "${BLUE}💡 Generating SSH key pair...${NC}"
    ssh-keygen -t rsa -b 4096 -f "$(eval echo "~/.ssh/id_rsa")" -N "" -C "aks-nap-demo"
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH_EXPANDED")
if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo -e "${RED}❌ Failed to read SSH public key${NC}"
    exit 1
fi

# Create resource group
echo -e "${GREEN}🏗️  Creating resource group...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

# Deploy using Bicep
echo -e "${GREEN}🚀 Deploying AKS cluster with NAP using Bicep...${NC}"
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "main.bicep" \
    --parameters "dev.bicepparam" \
    --parameters sshPublicKey="$SSH_PUBLIC_KEY" \
    --output table

# Get cluster credentials
echo -e "${GREEN}🔑 Getting cluster credentials...${NC}"
CLUSTER_NAME=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "main" --query "properties.outputs.clusterName.value" -o tsv)
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

echo ""
echo -e "${GREEN}✅ Infrastructure deployment completed!${NC}"
echo ""
echo -e "${BLUE}📋 Cluster Info:${NC}"
kubectl cluster-info
echo ""
echo -e "${BLUE}📋 Initial Nodes:${NC}"
kubectl get nodes -o wide
echo ""
echo -e "${BLUE}📋 NAP NodePools:${NC}"
kubectl get nodepool
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "2. Start demo workload: ./2-start-workload.sh"
echo "3. Stop demo workload: ./3-stop-workload.sh"
echo "4. Clean up resources: ./4-cleanup.sh"