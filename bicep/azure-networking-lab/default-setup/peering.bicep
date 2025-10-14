// Peering module to be deployed at resource group scope
@description('Name of the hub VNet')
param hubVnetName string

@description('Name of the spoke VNet')
param spokeVnetName string

@description('Resource ID of the hub VNet')
param hubVnetResourceId string

@description('Resource ID of the spoke VNet')
param spokeVnetResourceId string

// Hub VNet reference
resource hubVnet 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: hubVnetName
}

// Spoke VNet reference
resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: spokeVnetName
}

// Peering from hub to spoke
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-10-01' = {
  name: 'hub-to-${spokeVnetName}'
  parent: hubVnet
  properties: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnetResourceId
    }
  }
}

// Peering from spoke to hub
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-10-01' = {
  name: '${spokeVnetName}-to-hub'
  parent: spokeVnet
  properties: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetResourceId
    }
  }
  dependsOn: [hubToSpokePeering]
}

// Output the peering resource IDs
output hubToSpokePeeringId string = hubToSpokePeering.id
output spokeToHubPeeringId string = spokeToHubPeering.id
