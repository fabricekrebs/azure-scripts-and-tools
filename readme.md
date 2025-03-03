# Private Repository for Azure Cloud Scripts and Tools

Welcome to my private repository! This repository contains various scripts and tools I have created related to Azure Cloud. The content here primarily consists of automation scripts, tools, and examples designed to simplify and optimize tasks within Azure environments.

## Purpose

This repository serves as a place for me to store, organize, and share various utilities and code snippets I have developed for interacting with and managing Azure Cloud resources. These tools are focused on Azure Active Directory, Microsoft Graph API, and other Azure services.

## Repository Structure

### Bicep Templates

- **azure-vm-example**: Contains Bicep templates for deploying a virtual machine and associated resources.
  - `bicepconfig.json`: Configuration file for Bicep linter settings.
  - `dev.bicepparam`: Parameter file with environment-specific values.
  - `main.bicep`: Main Bicep template for deploying resources.
  - `virtualNetwork.bicep`: Bicep template for deploying a virtual network.

- **basic-bicep-example**: Contains a simple Bicep template for deploying a storage account and virtual network.
  - `main.bicep`: Main Bicep template for deploying resources.

- **vault-example**: Contains Bicep templates for deploying an Azure Key Vault.
  - `bicepconfig.json`: Configuration file for Bicep linter settings.
  - `dev.bicepparam`: Parameter file with environment-specific values.
  - `main.bicep`: Main Bicep template for deploying resources.

### PowerShell Scripts

- **getBlobFromEntraIDHostWithoutToken.ps1**: Script to download a blob from an Azure Storage Container using Entra ID without a token.
- **getBlobFromEntraIDWithCertificate.ps1**: Script to download a blob from an Azure Storage Container using a certificate for authentication.

## Usage

These scripts and templates are for personal use and learning, and may require customization to suit specific environments or use cases. Please review and update any environment variables and configurations before using them.

## Contributions

As this is a private repository, I do not expect contributions from others. However, feel free to reach out if you find any bugs or would like to discuss any of the scripts in more detail.

## License

This repository is not licensed for public use. It is intended for personal use only.

## Disclaimer

These scripts and templates are provided as-is and may require further customization based on specific Azure configurations and needs. I take no responsibility for any issues that arise from using these tools.