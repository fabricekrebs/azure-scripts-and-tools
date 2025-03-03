targetScope = 'resourceGroup'

@description('The location of the resource group to create.')
param location string

@description('The name of the virtual network to create.')
param vnetName string

@description('The address space for the virtual network.')
param addressSpace string = '10.0.0.0/16'

@description('The name of the subnet to create within the virtual network.')
param subnetName string

@description('The address prefix for the subnet.')
param subnetPrefix string = '10.0.0.0/24'

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.2' = {
  name: 'virtualNetworkDeployment'
  params: {
    // Required parameters
    addressPrefixes: [
      addressSpace
    ]
    name: vnetName
    // Non-required parameters
    location: location
    subnets: [
      {
        addressPrefix: subnetPrefix
        name: subnetName
      }
    ]
  }
}

output subnetName string = virtualNetwork.outputs.name
