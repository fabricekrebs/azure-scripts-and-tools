// the scope, the deployment deploys resources to
targetScope = 'resourceGroup'

// parameters and default values
param keyVaultName string

@description('Disable for development deployments.')
param enablePurgeProtection bool = true

// the resources to deploy
module myKeyVault 'br/public:avm/res/key-vault/vault:0.11.3' = {
  name: 'key-vault-deployment'
  params: {
    name: keyVaultName
    enablePurgeProtection: enablePurgeProtection
    // more properties are not needed, as AVM provides default values
  }
}
