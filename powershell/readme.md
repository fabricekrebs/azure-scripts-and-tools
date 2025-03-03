# PowerShell Scripts for Azure Blob Storage

This folder contains PowerShell scripts designed to interact with Azure Blob Storage using different authentication methods. These scripts are intended to simplify the process of downloading blobs from Azure Storage Containers.

## Scripts

### getBlobFromEntraIDHostWithoutToken.ps1

This script downloads a blob from an Azure Storage Container using Entra ID without a token.

#### Usage

1. Define your User Principal Name (UPN) by replacing the placeholder in the script.
2. Define the local path to save the blob.
3. Authenticate to Azure using Entra ID.
4. Define the storage account name, container name, and blob name.
5. Create a storage context using the connected account.
6. Download the blob content to the specified local path.

### getBlobFromEntraIDWithCertificate.ps1

This script downloads a blob from an Azure Storage Container using a certificate for authentication.

#### Usage

1. Create an Azure AD application and generate a certificate on the user's computer.
2. Push the public certificate to the Azure AD application and get the thumbprint.
3. Assign the IAM RBAC role to the Storage Container.
4. Replace the placeholders in the script with your actual values.
5. Authenticate to Azure using Entra ID with the certificate.
6. Create a storage context using the connected account.
7. Download the blob content to the specified local path.

## Disclaimer

These scripts are provided as-is and may require further customization based on specific Azure configurations and needs. Please review and update any environment variables and configurations before using them. I take no responsibility for any issues that arise from using these tools.