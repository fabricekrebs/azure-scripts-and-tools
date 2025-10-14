# Azure Networking Lab - Hub and Spoke Architecture

This Bicep template deploys a hub and spoke network architecture in Azure Italy North region using Azure Verified Modules (AVM).

## Architecture Overview

This deployment creates:

### Network Infrastructure
- **1 Resource Group**: `rg-italynorth-networklab-01`
- **1 Hub Virtual Network**: `vnet-italynorth-hub-01` (10.12.100.0/24)
  - GatewaySubnet: 10.12.100.0/27
  - AzureFirewallSubnet: 10.12.100.32/27
  - hub-subnet-01: 10.12.100.64/26
- **2 Spoke Virtual Networks**:
  - `vnet-italynorth-spoke-01` (10.12.101.0/24)
    - spoke-01-subnet-01: 10.12.101.0/25
    - spoke-01-subnet-02: 10.12.101.128/25
  - `vnet-italynorth-spoke-02` (10.12.102.0/24)
    - spoke-02-subnet-01: 10.12.102.0/25
    - spoke-02-subnet-02: 10.12.102.128/25

### VNet Peering
- **Bidirectional peering** between Hub and Spoke 1
- **Bidirectional peering** between Hub and Spoke 2  
- Gateway transit enabled from Hub to Spokes

### Virtual Machines
- **VM-Spoke-01**: Ubuntu 24.04 LTS in spoke-01-subnet-01 (Standard_B2s)
- **VM-Spoke-02**: Ubuntu 24.04 LTS in spoke-02-subnet-01 (Standard_B2s)
- SSH key-based authentication for secure access

### Azure Firewall
- **Azure Firewall**: `afw-italynorth-hub-01` deployed in AzureFirewallSubnet
- **SKU**: Standard tier with zone redundancy (zones 1, 2, 3)
- **Threat Intelligence**: Deny mode for malicious traffic blocking
- **Application Rules**: HTTP/HTTPS traffic allowed from any source
- **Network Rules**: DNS (port 53) and NTP (port 123) traffic allowed
- **Public IP**: Automatically created with Standard SKU

### Route Tables (Optional)
- **Firewall Routing**: Configurable via `enableFirewallRouting` parameter (default: true)
- **Route Tables**: One per spoke network (`rt-vnet-italynorth-spoke-01`, `rt-vnet-italynorth-spoke-02`)
- **Default Route**: 0.0.0.0/0 → Azure Firewall private IP
- **Traffic Flow**: All spoke traffic routes through Azure Firewall for inspection

## Prerequisites

1. **Azure CLI** or **Azure PowerShell** installed
2. **Bicep CLI** installed
3. Appropriate Azure permissions to create:
   - Resource Groups
   - Virtual Networks
   - Virtual Network Peerings

## Files Structure

```
default-setup/
├── main.bicep              # Main Bicep template
├── main.bicepparam         # Parameters file
├── bicepconfig.json        # Bicep configuration
└── README.md              # This file
```

## Pre-Deployment Configuration

### SSH Key Setup

Before deploying, you need to provide an SSH public key for VM authentication:

1. **Generate an SSH key pair** (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

2. **Copy your public key**:
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```

3. **Update the parameter file**: Edit `main.bicepparam` and replace the placeholder SSH key:
   ```bicep
   param sshPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-actual-ssh-public-key-here'
   ```

## Deployment Instructions

### Using Azure CLI

1. **Login to Azure**:
   ```bash
   az login
   ```

2. **Set the subscription** (if needed):
   ```bash
   az account set --subscription "your-subscription-id"
   ```

3. **Deploy the template**:
   ```bash
   az deployment sub create \
     --location italynorth \
     --template-file main.bicep \
     --parameters main.bicepparam \
     --name "networklab-deployment-01"
   ```

### Using Azure PowerShell

1. **Login to Azure**:
   ```powershell
   Connect-AzAccount
   ```

2. **Set the subscription** (if needed):
   ```powershell
   Set-AzContext -SubscriptionId "your-subscription-id"
   ```

3. **Deploy the template**:
   ```powershell
   New-AzDeployment `
     -Location "italynorth" `
     -TemplateFile "main.bicep" `
     -TemplateParameterFile "main.bicepparam" `
     -Name "networklab-deployment-01"
   ```

## What Gets Deployed

### Azure Verified Modules Used

This template uses the following Azure Verified Modules:

1. **Resource Group Module**: `br/public:avm/res/resources/resource-group:0.4.2`
2. **Virtual Network Module**: `br/public:avm/res/network/virtual-network:0.7.1`
3. **Virtual Machine Module**: `br/public:avm/res/compute/virtual-machine:0.20.0`
4. **Azure Firewall Module**: `br/public:avm/res/network/azure-firewall:0.7.0`
5. **Route Table Module**: `br/public:avm/res/network/route-table:0.4.0`

### Resource Details

| Resource Type | Name | Address Space | Subnets |
|---------------|------|---------------|---------|
| Resource Group | rg-italynorth-networklab-01 | N/A | N/A |
| Hub VNet | vnet-italynorth-hub-01 | 10.12.100.0/24 | GatewaySubnet, AzureFirewallSubnet, hub-subnet-01 |
| Spoke VNet 1 | vnet-italynorth-spoke-01 | 10.12.101.0/24 | spoke-01-subnet-01, spoke-01-subnet-02 |
| Spoke VNet 2 | vnet-italynorth-spoke-02 | 10.12.102.0/24 | spoke-02-subnet-01, spoke-02-subnet-02 |
| Azure Firewall | afw-italynorth-hub-01 | N/A | AzureFirewallSubnet |
| VM Spoke 1 | vm-vnet-italynorth-spoke-01 | N/A | spoke-01-subnet-01 |
| VM Spoke 2 | vm-vnet-italynorth-spoke-02 | N/A | spoke-02-subnet-01 |

## Configuration

You can modify the deployment by editing the `main.bicepparam` file:

- **Location**: Change the `location` parameter to deploy to a different region
- **Resource Names**: Modify the `resourceGroupName` and VNet names
- **Network Addressing**: Adjust the address spaces and subnet configurations
- **Firewall Configuration**: Customize `azureFirewallConfig` with different rules
- **Routing**: Set `enableFirewallRouting` to false to disable route tables
- **Tags**: Update the tags to match your organization's standards

## Next Steps

After deployment, you may want to add:

1. **Virtual Network Peering**: Connect the hub and spoke networks
2. **Network Security Groups**: Apply security rules to subnets
3. **Route Tables**: Configure custom routing
4. **Azure Firewall**: Deploy firewall in the hub for centralized security
5. **VPN Gateway**: Enable hybrid connectivity

## Cleanup

To remove all deployed resources:

```bash
az group delete --name rg-italynorth-networklab-01 --yes --no-wait
```

## Notes

- This template deploys basic network infrastructure without peering configured
- Peering can be added in a separate deployment or by modifying the template
- The hub VNet includes special subnets (GatewaySubnet, AzureFirewallSubnet) for future gateway and firewall deployments
- All resources are tagged for easier management and cost tracking

## Troubleshooting

### Common Issues

1. **Module restore errors**: Ensure you have internet connectivity and access to the Azure Bicep registry
2. **Permission errors**: Verify you have Contributor rights on the subscription
3. **Region availability**: Ensure all resource types are available in Italy North region

### Validation

You can validate the template before deployment:

```bash
az deployment sub validate \
  --location italynorth \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --name "networklab-deployment-01"
```