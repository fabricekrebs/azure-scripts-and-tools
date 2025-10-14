targetScope = 'subscription'

@description('The location/region to deploy resources.')
param location string = 'italynorth'

@description('The name of the resource group.')
param resourceGroupName string = 'rg-italynorth-networklab-01'

@description('Hub virtual network configuration.')
// Hub Virtual Network Configuration
param hubVnetConfig object = {
  name: 'vnet-italynorth-hub-01'
  addressPrefixes: ['10.12.100.0/24']
  subnets: [
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.12.100.0/26'      // 10.12.100.0 - 10.12.100.63 (64 IPs)
    }
    {
      name: 'hub-subnet-01'
      addressPrefix: '10.12.100.64/26'    // 10.12.100.64 - 10.12.100.127 (64 IPs)
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '10.12.100.128/26'     // 10.12.100.128 - 10.12.100.191 (64 IPs) - Fixed CIDR
    }
  ]
}

@description('Spoke virtual network configurations.')
param spokeVnetConfigs array = [
  {
    name: 'vnet-italynorth-spoke-01'
    addressPrefixes: ['10.12.101.0/24']
    subnets: [
      {
        name: 'spoke-01-subnet-01'
        addressPrefix: '10.12.101.0/25'
      }
      {
        name: 'spoke-01-subnet-02'
        addressPrefix: '10.12.101.128/25'
      }
    ]
  }
  {
    name: 'vnet-italynorth-spoke-02'
    addressPrefixes: ['10.12.102.0/24']
    subnets: [
      {
        name: 'spoke-02-subnet-01'
        addressPrefix: '10.12.102.0/25'
      }
      {
        name: 'spoke-02-subnet-02'
        addressPrefix: '10.12.102.128/25'
      }
    ]
  }
]

@description('Virtual machine configuration.')
param vmConfig object = {
  adminUsername: 'azureuser'
  vmSize: 'Standard_B2s'
  imageReference: {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-noble'
    sku: '24_04-lts-gen2'
    version: 'latest'
  }
}

@description('SSH public key for VM authentication.')
@secure()
param sshPublicKey string

@description('Azure Firewall configuration.')
param azureFirewallConfig object = {
  name: 'afw-italynorth-hub-01'
  skuTier: 'Standard'
  threatIntelMode: 'Deny'
  applicationRules: [
    {
      name: 'allow-web-traffic'
      properties: {
        action: {
          type: 'Allow'
        }
        priority: 100
        rules: [
          {
            name: 'allow-http-https'
            protocols: [
              {
                port: 80
                protocolType: 'Http'
              }
              {
                port: 443
                protocolType: 'Https'
              }
            ]
            sourceAddresses: ['*']
            targetFqdns: ['*']
          }
        ]
      }
    }
  ]
  networkRules: [
    {
      name: 'allow-dns-ntp'
      properties: {
        action: {
          type: 'Allow'
        }
        priority: 200
        rules: [
          {
            name: 'allow-dns'
            protocols: ['UDP']
            sourceAddresses: ['*']
            destinationAddresses: ['*']
            destinationPorts: ['53']
          }
          {
            name: 'allow-ntp'
            protocols: ['UDP']
            sourceAddresses: ['*']
            destinationAddresses: ['*']
            destinationPorts: ['123']
          }
        ]
      }
    }
  ]
}

@description('Enable routing through Azure Firewall.')
param enableFirewallRouting bool = true

@description('Tags to apply to all resources.')
param tags object = {
  Environment: 'Lab'
  Project: 'NetworkingLab'
  Location: 'ItalyNorth'
  CreatedBy: 'AzureNetworkingLab'
}

// Deploy Resource Group
module rg 'br/public:avm/res/resources/resource-group:0.4.2' = {
  name: 'rg-deployment'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Deploy Hub Virtual Network
module hubVnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'hub-vnet-deployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: hubVnetConfig.name
    location: location
    addressPrefixes: hubVnetConfig.addressPrefixes
    subnets: hubVnetConfig.subnets
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

// Deploy Spoke Virtual Networks (initial deployment without routing)
module spokeVnets 'br/public:avm/res/network/virtual-network:0.7.1' = [for (spoke, i) in spokeVnetConfigs: {
  name: 'spoke-vnet-deployment-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: spoke.name
    location: location
    addressPrefixes: spoke.addressPrefixes
    subnets: spoke.subnets
    tags: tags
  }
  dependsOn: [
    rg
  ]
}]

// Deploy VNet Peerings using dedicated peering module
module spokePeerings 'peering.bicep' = [for (spoke, i) in spokeVnetConfigs: {
  name: 'spoke-peering-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    hubVnetName: hubVnetConfig.name
    spokeVnetName: spoke.name
    hubVnetResourceId: hubVnet.outputs.resourceId
    spokeVnetResourceId: spokeVnets[i].outputs.resourceId
  }
  dependsOn: [
    rg
    spokeVnets
  ]
}]

// Deploy Virtual Machines in Spoke Networks
module spokeVMs 'br/public:avm/res/compute/virtual-machine:0.20.0' = [for (spoke, i) in spokeVnetConfigs: {
  name: 'vm-deployment-spoke-${i + 1}'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    name: 'vm-${spoke.name}'
    adminUsername: vmConfig.adminUsername
    availabilityZone: 1
    imageReference: vmConfig.imageReference
    vmSize: vmConfig.vmSize
    osType: 'Linux'
    nicConfigurations: [
      {
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: '${spokeVnets[i].outputs.resourceId}/subnets/${spoke.subnets[0].name}'
          }
        ]
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: vmConfig.osDiskType
      }
    }
    
    // Non-required parameters
    location: location
    disablePasswordAuthentication: true
    publicKeys: [
      {
        keyData: sshPublicKey
        path: '/home/${vmConfig.adminUsername}/.ssh/authorized_keys'
      }
    ]
    tags: union(tags, {
      VMRole: 'SpokeVM'
      SpokeNetwork: spoke.name
    })
  }
  dependsOn: [
    rg
    spokeVnets
    spokePeerings
  ]
}]

// Deploy Azure Firewall in Hub Virtual Network
module azureFirewall 'br/public:avm/res/network/azure-firewall:0.7.0' = {
  name: 'azure-firewall-deployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: azureFirewallConfig.name
    location: location
    virtualNetworkResourceId: hubVnet.outputs.resourceId
    azureSkuTier: azureFirewallConfig.skuTier
    threatIntelMode: azureFirewallConfig.threatIntelMode
    applicationRuleCollections: azureFirewallConfig.applicationRules
    networkRuleCollections: azureFirewallConfig.networkRules
    zones: [1, 2, 3]
    publicIPAddressObject: {
      name: '${azureFirewallConfig.name}-pip'
      publicIPAllocationMethod: 'Static'
      skuName: 'Standard'
      skuTier: 'Regional'
    }
    tags: union(tags, {
      FirewallRole: 'HubFirewall'
      SecurityLayer: 'Network'
    })
  }
  dependsOn: [
    rg
  ]
}

// Deploy Route Tables for Spoke Networks (routes traffic through firewall)
module spokeRouteTables 'br/public:avm/res/network/route-table:0.4.0' = [for (spoke, i) in spokeVnetConfigs: if (enableFirewallRouting) {
  name: 'route-table-deployment-spoke-${i + 1}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'rt-${spoke.name}'
    location: location
    routes: [
      {
        name: 'default-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall.outputs.privateIp
        }
      }
    ]
    tags: union(tags, {
      RoutingRole: 'SpokeRouting'
      SpokeNetwork: spoke.name
    })
  }
  dependsOn: [
    rg
    spokeVnets[i]
  ]
}]

// Associate Route Tables with Spoke Subnets when firewall routing is enabled
module spokeSubnetRouteAssociations 'subnet-route-association.bicep' = [for (spoke, i) in spokeVnetConfigs: if (enableFirewallRouting) {
  name: 'subnet-route-association-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    vnetName: spoke.name
    subnets: spoke.subnets
    routeTableId: spokeRouteTables[i].outputs.resourceId
  }
  dependsOn: [
    spokeVnets
    spokeRouteTables[i]
  ]
}]

// Outputs
@description('The resource ID of the deployed resource group.')
output resourceGroupId string = rg.outputs.resourceId

@description('The name of the deployed resource group.')
output resourceGroupName string = rg.outputs.name

@description('The resource ID of the hub virtual network.')
output hubVirtualNetworkId string = hubVnet.outputs.resourceId

@description('The name of the hub virtual network.')
output hubVirtualNetworkName string = hubVnet.outputs.name

@description('The resource IDs of the spoke virtual networks.')
output spokeVirtualNetworkIds array = [for i in range(0, length(spokeVnetConfigs)): spokeVnets[i].outputs.resourceId]

@description('The names of the spoke virtual networks.')
output spokeVirtualNetworkNames array = [for i in range(0, length(spokeVnetConfigs)): spokeVnets[i].outputs.name]

@description('The location where resources were deployed.')
output location string = location

@description('The resource ID of the Azure Firewall.')
output azureFirewallId string = azureFirewall.outputs.resourceId

@description('The name of the Azure Firewall.')
output azureFirewallName string = azureFirewall.outputs.name

@description('The private IP address of the Azure Firewall.')
output azureFirewallPrivateIp string = azureFirewall.outputs.privateIp

@description('Route tables are created when enableFirewallRouting is true.')
output firewallRoutingEnabled bool = enableFirewallRouting
