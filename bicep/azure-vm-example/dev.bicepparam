using 'main.bicep'

// environment specific values

param location = 'italynorth'
param vnetName = 'vnet-managedbybicep'
param subnetName = 'subnet-managedbybicep'
param vmName = 'vm-managedbybicep'
param computerName = 'demovm'
param adminUsername = 'adminUser'
// SECURITY: Password should be provided securely at deployment time using:
// az deployment group create ... --parameters adminPassword='<secure-password>'
// or use Key Vault reference: getSecret('keyVaultId', 'secretName')
param adminPassword = '' // TODO: Provide secure password at deployment
param vmSize = 'Standard_DS1_v2'
