# Private Repository for Azure Cloud Scripts and Tools

Welcome to my private repository! This repository contains various scripts and tools I have created related to Azure Cloud. The content here primarily consists of automation scripts, tools, and examples designed to simplify and optimize tasks within Azure environments.

## Purpose

This repository serves as a place for me to store, organize, and share various utilities and code snippets I have developed for interacting with and managing Azure Cloud resources. These tools focus on Azure Kubernetes Service (AKS), Azure Batch, Bicep Infrastructure as Code, Azure Storage, Azure Guest Configuration, and other Azure services.

## Repository Structure

### AKS (Azure Kubernetes Service)

- **aks-nap-demo**: Demonstration of AKS with Node Auto Provisioning (NAP) using Karpenter for intelligent node auto-scaling.
  - Features fast scaling, smart instance selection, and spot instance support
  - Includes complete lifecycle scripts (deploy, scale-up, scale-down, cleanup)
  - Demonstrates automatic node provisioning based on workload demands

### Azure Batch

- **azurebatch**: Production-ready Azure Batch solution for parallel JPG to PNG image conversion.
  - Parallel processing across multiple compute nodes
  - Secure authentication using Azure Managed Identity
  - High performance: tested with 5,000 images in ~100 seconds using 10 nodes
  - Includes deployment scripts, Python conversion script, and comprehensive documentation

### Bicep Templates

- **azure-networking-lab**: Advanced networking setup with virtual networks, subnets, peering, and firewall configurations.
  - Default setup with comprehensive network infrastructure
  - Includes route associations and firewall testing configurations

- **azure-vm-example**: Bicep templates for deploying virtual machines and associated resources.
  - Virtual network and subnet configuration
  - VM deployment with customizable parameters

- **basic-bicep-example**: Simple Bicep template for deploying a storage account and virtual network.

- **vault-example**: Bicep templates for deploying Azure Key Vault with security configurations.

### DSC (Desired State Configuration)

- **dsc**: Azure Guest Configuration package creation and deployment.
  - PowerShell DSC for configuration management
  - Example: Enforce Windows Firewall Domain Profile settings
  - Includes package creation, testing, and Azure Policy assignment workflows

### PowerShell Scripts

- **getBlobFromEntraIDHostWithoutToken.ps1**: Download blobs from Azure Storage using Entra ID authentication without tokens.
- **getBlobFromEntraIDWithCertificate.ps1**: Download blobs from Azure Storage using certificate-based authentication.

## Usage

These scripts and templates are for personal use and learning, and may require customization to suit specific environments or use cases. Please review and update any environment variables and configurations before using them.

## Contributions

As this is a private repository, I do not expect contributions from others. However, feel free to reach out if you find any bugs or would like to discuss any of the scripts in more detail.

## License

This repository is not licensed for public use. It is intended for personal use only.

## Disclaimer

These scripts and templates are provided as-is and may require further customization based on specific Azure configurations and needs. I take no responsibility for any issues that arise from using these tools.