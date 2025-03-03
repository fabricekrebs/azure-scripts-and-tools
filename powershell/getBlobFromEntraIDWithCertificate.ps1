# This script downloads a blob from an Azure Storage Container using a certificate for authentication.
# Steps to set up:
# 1. Create an Azure AD application and generate a certificate on the user's computer.
# 2. Push the public certificate to the Azure AD application and get the thumbprint.
# 3. Assign the IAM RBAC role to the Storage Container.
# 4. Replace the placeholders in the script with your actual values.

# Define the local path to save the blob
$localPath = 'xxx'  # Replace with your actual local path

# Define the storage account name
$storageAccountName = "xxx"  # Replace with your actual storage account name

# Define the container name and blob name
$containerName = "xxx"  # Replace with your actual container name
$blobName = "xxx"  # Replace with your actual blob name

# Define the certificate thumbprint
$certificateThumbprint = 'xxx'  # Replace with your actual certificate thumbprint

# Define the application ID
$applicationId = 'xxx'  # Replace with your actual application ID

# Define the tenant ID
$tenantId = 'xxx'  # Replace with your actual tenant ID

# Authenticate to Azure using Entra ID
Connect-AzAccount -CertificateThumbprint $certificateThumbprint -ApplicationId $applicationId -TenantId $tenantId

# Create a storage context using the connected account
$context = New-AzStorageContext -StorageAccountName $storageAccountName

# Download the blob content to the specified local path
Get-AzStorageBlobContent -Container $containerName -Blob $blobName -Destination $localPath -Context $context