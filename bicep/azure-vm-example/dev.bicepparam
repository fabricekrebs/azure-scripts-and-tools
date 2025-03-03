using 'main.bicep'

// environment specific values

param location = 'italynorth'
param vnetName = 'vnet-managedbybicep'
param subnetName = 'subnet-managedbybicep'
param vmName = 'vm-managedbybicep'
param computerName = 'demovm'
param adminUsername = 'adminUser'
param adminPassword = 'P@ssw0rd123!'
param vmSize = 'Standard_DS1_v2'
