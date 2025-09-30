#!/bin/bash

# Simple AKS NAP Demo - Cleanup
# Removes all Azure resources created by the demo

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
LOCATION_SHORT="italynorth"
RESOURCE_GROUP="rg-${LOCATION_SHORT}-aksnapdemo-01"

echo -e "${GREEN}🚀 AKS NAP Demo - Cleanup Resources${NC}"
echo "==================================="
echo ""

# Check if logged into Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged into Azure. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Current subscription: $(az account show --query name -o tsv)${NC}"
echo -e "${BLUE}📋 Resource Group to delete: $RESOURCE_GROUP${NC}"
echo ""

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${YELLOW}ℹ️  Resource group $RESOURCE_GROUP does not exist or already deleted${NC}"
    exit 0
fi

# Show resources that will be deleted
echo -e "${BLUE}📋 Resources to be deleted:${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --output table
echo ""

# Confirmation prompt
echo -e "${YELLOW}⚠️  WARNING: This will permanently delete ALL resources in $RESOURCE_GROUP${NC}"
echo -e "${YELLOW}⚠️  Including: AKS cluster, Virtual Network, Log Analytics Workspace, and all associated resources${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo -e "${BLUE}ℹ️  Cleanup cancelled${NC}"
    exit 0
fi

# Delete resource group and all resources
echo ""
echo -e "${GREEN}🗑️  Deleting resource group and all resources...${NC}"
echo -e "${YELLOW}⏳ This may take several minutes...${NC}"

az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo ""
echo -e "${GREEN}✅ Deletion initiated successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Status:${NC}"
echo "  - Resource group deletion started in background"
echo "  - This process typically takes 5-10 minutes"
echo ""
echo -e "${BLUE}💡 Monitor deletion progress with:${NC}"
echo "  az group show --name $RESOURCE_GROUP --query 'properties.provisioningState' -o tsv"
echo ""
echo -e "${BLUE}💡 Check if deletion is complete:${NC}"
echo "  az group exists --name $RESOURCE_GROUP"
echo ""
echo -e "${GREEN}🎉 Thank you for trying the AKS NAP Demo!${NC}"