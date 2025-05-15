# Azure Guest Configuration Package Creation & Deployment

## Prerequisites

- Install the required PowerShell module:

  ```powershell
  Install-Module -Name GuestConfiguration
  ```

## Package Creation

1. Run the relevant `.ps1` script to generate the desired Guest Configuration package.

## Testing the Package

- **Check configuration compliance:**
  ```powershell
  Get-GuestConfigurationPackageComplianceStatus -Path .\<package-name-zip>
  ```

- **Apply the configuration locally:**
  ```powershell
  Start-GuestConfigurationPackageRemediation -Path .\<package-name-zip>
  ```

## Uploading the Package to Azure Blob Storage

1. Upload the package to a storage account accessible by Azure Policy:

   ```powershell
   $connectionString = '<your-storage-connection-string>'
   $context = New-AzStorageContext -ConnectionString $connectionString
   $getParams = @{
       Context   = $context
       Container = '<container-name>'
       Blob      = '<package-name-zip>'
   }
   $blob = Get-AzStorageBlob @getParams
   $contentUri = $blob.ICloudBlob.Uri.AbsoluteUri
   ```

## Creating and Assigning the Guest Configuration Policy

1. Generate a new GUID for the policy:

   ```powershell
   $policyId = New-Guid
   ```

2. Define the policy configuration:

   ```powershell
   $PolicyConfig = @{
     PolicyId      = $policyId
     ContentUri    = $contentUri
     DisplayName   = '<display name of the policy>'
     Description   = '<description of the policy>'
     Platform      = 'Windows'
     PolicyVersion = '1.0.0'
     Mode          = 'ApplyAndAutoCorrect' # Options: ApplyAndMonitor, ApplyAndAutoCorrect, Audit
   }
   New-GuestConfigurationPolicy @PolicyConfig
   ```

3. Create the Azure Policy definition:

   ```powershell
   New-AzPolicyDefinition -Name '<display name of the policy>' -Policy '<generated-policy-json-file>'
   ```

4. In the Azure Portal, navigate to **Policy** to view and assign the new policy.

   - Assign the policy to your target machine, Arc server, or resource group under **Operations > Policies**.

---

**References:**
- [How to develop a custom machine configuration package](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/develop-custom-package/overview)
- [How to create an Azure Policy Definition](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/create-policy-definition)
