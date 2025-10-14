using 'main.bicep'

// Parameters for the Azure Networking Lab deployment
param location = 'italynorth'
param resourceGroupName = 'rg-italynorth-networklab-01'

// Hub Virtual Network Configuration
param hubVnetConfig = {
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

// Spoke Virtual Networks Configuration
param spokeVnetConfigs = [
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

// Virtual Machine Configuration
param vmConfig = {
  adminUsername: 'azureuser'
  vmSize: 'Standard_B2s'
  osDiskType: 'Premium_LRS'
  imageReference: {
    publisher: 'Canonical'
    offer: 'ubuntu-24_04-lts'
    sku: 'server'
    version: 'latest'
  }
}

// SSH Public Key - Replace with your actual SSH public key
// Generate one with: ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
param sshPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmZfCoJvz/bbTlZ5xHPnCokUEron30o0OIXLZDX+oF9fZ6IRjajGVKR6PmjtJlN+Pxi3Rbo10m6JUAToQH8u6XluHDv3D9aTK+FoLoZhtRXWLZWni97EVkBBj0hSEKKXgMY48C/pHYbfgN5OzZyZldD5Hzsp8Uz7HBGaSalvDRrLemjsOss6AAUWKXp2OFRctcOntnJ5jebYGDza8HhrWa3YJIAfJ4pAzkgidSk/Oz2P3W7C4mrHDdH7xphDfwwrhNDGCAbnh2N6puCzZGevaEaCfRM1A6J1gPMYUiO1wintbZjVSk9FDVN70XDq4UOjObRRyUXUBXlglGp2bEdbPp krfa@fabrice'

// Resource Tags
param tags = {
  Environment: 'Lab'
  Project: 'NetworkingLab'
  Location: 'ItalyNorth'
  CreatedBy: 'AzureNetworkingLab'
}
