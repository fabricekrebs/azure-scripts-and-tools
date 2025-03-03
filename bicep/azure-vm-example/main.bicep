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

@description('The name of the virtual machine to create.')
param vmName string

@description('The size of the virtual machine to create.')
param vmSize string = 'Standard_DS1_v2'

@description('The computer name for the virtual machine.')
param computerName string

@description('The admin username for the virtual machine.')
param adminUsername string

@secure()
@description('The admin password for the virtual machine.')
param adminPassword string

var imageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}

var uniqueStr = toLower(uniqueString(resourceGroup().id))

module virtualNetwork 'virtualNetwork.bicep' = {
  name: 'virtualNetworkDeployment${uniqueStr}'
  params: {
    location: location
    vnetName: vnetName
    addressSpace: addressSpace
    subnetName: subnetName
    subnetPrefix: subnetPrefix
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource demoVM 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output subnetName string = virtualNetwork.name
