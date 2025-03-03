# This script downloads a blob from an Azure Storage Container using Entra ID for authentication.
# Steps to set up:
# 1. Ensure you have the Azure PowerShell module installed.
# 2. Replace 'your-upn@domain.com' with your actual User Principal Name (UPN).
# 3. Replace 'xxx' placeholders with your actual local path, storage account name, container name, and blob name.
# 4. Run the script to authenticate to Azure and download the blob content to the specified local path.

# Define your User Principal Name (UPN)
$accountId = 'your-upn@domain.com'  # Replace with your actual UPN

# Define the local path to save the blob
$localpath = 'xxx'  # Replace with your actual local path

# Authenticate to Azure using Entra ID
Connect-AzAccount -AccountId $accountId

# Define the storage account name
$storageAccountName = "xxx"  # Replace with your actual storage account name

# Define the container name and blob name
$containerName = "xxx"  # Replace with your actual container name
$blobName = "xxx"  # Replace with your actual blob name

# Create a storage context using the connected account
$context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

# Download the blob content to the specified local path
Get-AzStorageBlobContent -Container $containerName -Blob $blobName -Destination $localPath -Context $context