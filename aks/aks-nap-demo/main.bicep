targetScope = 'resourceGroup'

@description('The name of the AKS cluster')
param clusterName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('The DNS prefix for the AKS cluster')
param dnsPrefix string

@description('The admin username for the node VMs')
param adminUsername string

@description('The SSH public key for the node VMs')
@secure()
param sshPublicKey string

@description('The Kubernetes version for the cluster')
param kubernetesVersion string

@description('The VM size for system nodes')
param systemNodeVmSize string

@description('The initial node count for system pool')
param systemNodeCount int

@description('Tags to apply to all resources')
param tags object

// Virtual Network for the AKS cluster
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${clusterName}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// AKS Cluster with NAP enabled
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-08-02-preview' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    
    // Enable NAP (Node Auto Provisioning)
    nodeProvisioningProfile: {
      mode: 'Auto'
    }
    
    // Default system node pool
    agentPoolProfiles: [
      {
        name: 'system'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        osDiskSizeGB: 30
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: vnet.properties.subnets[0].id
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false  // Must be false when NAP is enabled
      }
    ]
    
    // Network configuration
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
    }
    
    // Linux profile for SSH access
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    
    // Enable useful features
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
    }
    
    // Enable workload identity
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// Log Analytics Workspace for monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${clusterName}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Role assignments for NAP to work properly
resource napContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aksCluster.id, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: aksCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Output important information
output clusterName string = aksCluster.name
output clusterFQDN string = aksCluster.properties.fqdn
output clusterResourceGroup string = resourceGroup().name
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
