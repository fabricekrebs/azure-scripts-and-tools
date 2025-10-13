using 'main.bicep'

// Basic cluster configuration
param clusterName = 'aks-nap-demo'
param location = 'Italy North'
param dnsPrefix = 'aks-nap-demo-dns'
param adminUsername = 'azureuser'

// Kubernetes configuration
param kubernetesVersion = '1.31'

// System node pool configuration
param systemNodeVmSize = 'Standard_DS2_v2'
param systemNodeCount = 2

// SSH public key - will be passed from deployment script
param sshPublicKey = ''

// Tags for resource organization
param tags = {
  environment: 'demo'
  purpose: 'aks-nap-testing'
  demo: 'simplified'
  location: 'italynorth'
}
