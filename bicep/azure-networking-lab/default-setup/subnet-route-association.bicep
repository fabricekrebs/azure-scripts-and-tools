@description('The name of the virtual network containing the subnets')
param vnetName string

@description('Array of subnets to associate with the route table')
param subnets array

@description('The resource ID of the route table to associate with the subnets')
param routeTableId string

// Associate route table with each subnet in the spoke VNet
resource subnetRouteAssociations 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = [for subnet in subnets: {
  name: '${vnetName}/${subnet.name}'
  properties: {
    addressPrefix: subnet.addressPrefix
    routeTable: {
      id: routeTableId
    }
  }
}]

@description('The resource IDs of the updated subnets')
output subnetIds array = [for (subnet, i) in subnets: subnetRouteAssociations[i].id]
