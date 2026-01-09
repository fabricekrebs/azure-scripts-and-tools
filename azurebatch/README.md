# Azure Batch: Parallel JPG to PNG Converter

A production-ready Azure Batch solution that converts JPG images to PNG format using parallel processing across multiple compute nodes. The system automatically scales to match your pool size and can process thousands of images in minutes using secure managed identity authentication.

## Features

✅ **Parallel Processing**: Automatically distributes work across all pool nodes
✅ **Dynamic Scaling**: Adapts to pool size changes automatically
✅ **Secure Authentication**: Uses Azure Managed Identity (no secrets in code)
✅ **Separate Containers**: Reads from input, writes to output (preserves originals)
✅ **High Performance**: Tested with 5,000 images in ~100 seconds using 10 nodes
✅ **Easy Deployment**: Single command to deploy and run

## Prerequisites

- Azure Subscription
- Azure Batch Account
- Azure Storage Account
- Azure Blob Storage containers
- Python 3.7+ (for local testing only)
- Azure CLI

## Installation

1. Install the required dependencies:

```bash
pip install -r requirements.txt
```

## Configuration

Set the following environment variables:

### Recommended - Using Managed Identity (Azure Batch):
- `AZURE_STORAGE_ACCOUNT_NAME`: Your Azure Storage Account name
- `AZURE_STORAGE_INPUT_CONTAINER`: Input container with JPG files (default: `images`)
- `AZURE_STORAGE_OUTPUT_CONTAINER`: Output container for PNG files (default: `converted`)

See [MANAGED_IDENTITY_SETUP.md](MANAGED_IDENTITY_SETUP.md) for detailed setup instructions.

### Alternative - Using Connection String:
- `AZURE_STORAGE_CONNECTION_STRING`: Your Azure Storage Account connection string
- `AZURE_STORAGE_CONTAINER_NAME`: Name of the container (default: `images`)

### Getting Your Connection String

You can find your Azure Storage connection string in the Azure Portal:
1. Go to your Storage Account
2. Navigate to **Security + networking** → **Access keys**
3. Copy the connection string from either key1 or key2

## Usage

### Linux/macOS:

**Option A - Managed Identity (for Azure Batch):**
```bash
export AZURE_STORAGE_ACCOUNT_NAME="your_storage_account_name"
export AZURE_STORAGE_INPUT_CONTAINER="images"
export AZURE_STORAGE_OUTPUT_CONTAINER="converted"
python convert_image.py
```

**Option B - Connection String:**
```bash
export AZURE_STORAGE_CONNECTION_STRING="your_connection_string_here"
export AZURE_STORAGE_INPUT_CONTAINER="images"
export AZURE_STORAGE_OUTPUT_CONTAINER="converted"
python convert_image.py
```

**Option C - Parallel Processing (Azure Batch with multiple nodes):**
```bash
# Scale pool to desired number of nodes
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 5

# Run parallel deployment (automatically creates tasks matching node count)
./deploy_parallel.sh
```

### Windows (PowerShell):

```powershell
$env:AZURE_STORAGE_CONNECTION_STRING="your_connection_string_here"
$env:AZURE_STORAGE_CONTAINER_NAME="your_container_name"
python convert_image.py
```

### Windows (Command Prompt):

```cmd
set AZURE_STORAGE_CONNECTION_STRING=your_connection_string_here
set AZURE_STORAGE_CONTAINER_NAME=your_container_name
python convert_image.py
```

## How It Works

### Single File Mode (default)
1. **Connects** to Azure Blob Storage using managed identity or connection string
2. **Lists** all files in the input container
3. **Sorts** the files alphabetically
4. **Finds** the first JPG/JPEG file in the sorted list
5. **Downloads** the JPG file
6. **Converts** it to PNG format using Pillow
7. **Uploads** the PNG to the output container

### Parallel Processing Mode
When using `--task-id` and `--total-tasks` arguments:
1. **Connects** to Azure Blob Storage
2. **Lists** all JPG files in the input container
3. **Distributes** files across tasks (round-robin)
   - Task 0: files 0, 5, 10, 15...
   - Task 1: files 1, 6, 11, 16...
   - Task 2: files 2, 7, 12, 17...
4. **Processes** only files assigned to this task
5. **Converts** all assigned JPGs to PNG
6. **Uploads** PNGs to the output container

## Quick Start

### 1. Create Test Images
```bash
# Create 1000 test JPG images
./create_dummy_batch.sh 1000 demo-image
```

### 2. Scale Your Pool
```bash
# Scale to 10 nodes for optimal performance
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 10

# Wait for nodes to be ready
watch -n 5 'az batch pool show --pool-id image-processing-pool --query "{Current:currentDedicatedNodes, Target:targetDedicatedNodes}"'
```

### 3. Run Parallel Conversion
```bash
# Automatically creates tasks matching pool size
./deploy_parallel.sh
```

### 4. Verify Results
```bash
# Count converted images
az storage blob list --account-name <your-storage-account> --container-name converted --auth-mode login --query "[?ends_with(name, '.png')]" | grep -c "name"
```

## Complete Reproduction Guide

### Step 1: Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="rg-batch-demo"
LOCATION="eastus"
BATCH_ACCOUNT="batchdemo001"
STORAGE_ACCOUNT="storagedemo001"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Create containers
az storage container create --name scripts --account-name $STORAGE_ACCOUNT --auth-mode login
az storage container create --name images --account-name $STORAGE_ACCOUNT --auth-mode login
az storage container create --name converted --account-name $STORAGE_ACCOUNT --auth-mode login

# Create batch account
az batch account create \
  --name $BATCH_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### Step 2: Configure Managed Identity

```bash
# Create user-assigned managed identity
IDENTITY_NAME="batch-pool-identity"
az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP

# Get identity details
IDENTITY_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
IDENTITY_PRINCIPAL=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)

# Assign Storage Blob Data Contributor role
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
```

### Step 3: Create Batch Pool

```bash
# Login to batch account
az batch account login --name $BATCH_ACCOUNT --resource-group $RESOURCE_GROUP

# Create pool with managed identity
az batch pool create \
  --id image-processing-pool \
  --vm-size Standard_D2s_v3 \
  --target-dedicated-nodes 10 \
  --image canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
  --node-agent-sku-id "batch.node.ubuntu 22.04" \
  --json-file pool-config.json
```

**pool-config.json:**
```json
{
  "id": "image-processing-pool",
  "vmSize": "Standard_D2s_v3",
  "targetDedicatedNodes": 10,
  "virtualMachineConfiguration": {
    "imageReference": {
      "publisher": "canonical",
      "offer": "0001-com-ubuntu-server-jammy",
      "sku": "22_04-lts",
      "version": "latest"
    },
    "nodeAgentSkuId": "batch.node.ubuntu 22.04"
  },
  "identity": {
    "type": "UserAssigned",
    "userAssignedIdentities": {
      "<IDENTITY_RESOURCE_ID>": {}
    }
  }
}
```

### Step 4: Create Batch Job

```bash
az batch job create --id image-conversion-job --pool-id image-processing-pool
```

### Step 5: Upload Scripts

```bash
# Upload all required scripts
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name convert_image.py --file convert_image.py --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name requirements.txt --file requirements.txt --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name install_dependencies.sh --file install_dependencies.sh --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name create_dummy_images.py --file create_dummy_images.py --auth-mode login --overwrite
```

### Step 6: Update Deployment Scripts

Edit `deploy_parallel.sh` and update these variables:
```bash
IDENTITY_RESOURCE_ID="<your-identity-resource-id>"
IDENTITY_CLIENT_ID="<your-identity-client-id>"
```

Update storage account name in the script:
```bash
# Replace 'saitalynorthbatch01' with your storage account name
```

### Step 7: Run the System

```bash
# 1. Create test images
./create_dummy_batch.sh 1000 demo-image

# 2. Run parallel conversion
./deploy_parallel.sh

# 3. Check results
az storage blob list --account-name $STORAGE_ACCOUNT --container-name converted --auth-mode login --query "[?ends_with(name, '.png')].{Name:name, Size:properties.contentLength}" -o table | head -20
```

## Performance Results

### Tested Configurations

| Images | Nodes | Time | Throughput |
|--------|-------|------|------------|
| 1,000 | 5 | ~15s | ~67 images/sec |
| 1,000 | 10 | ~15s | ~67 images/sec |
| 5,000 | 10 | ~100s | ~50 images/sec |

*Note: Performance depends on VM size, network bandwidth, and image complexity*

## Example Output

```
Starting Azure Blob Storage JPG to PNG conversion
Task: 1/10
Input Container: images
Output Container: converted

Listing blobs in container...
  Found: demo-image-000.jpg
  Found: demo-image-010.jpg
  ...

Files assigned to this task: 500

[1/500] Processing: demo-image-000.jpg
  Downloaded 29524 bytes
  Image size: (800, 600), Mode: RGB
  Converted to PNG (23131 bytes)
  Uploaded to output container as: demo-image-000.png

✓ All conversions completed successfully!
  Total files processed: 500
```

## Project Structure

```
.
├── README.md                      # This file
├── DEPLOYMENT_SUMMARY.md          # Detailed deployment guide
├── convert_image.py               # Main conversion script
├── create_dummy_images.py         # Test image generator
├── requirements.txt               # Python dependencies
├── install_dependencies.sh        # Dependency installer for batch nodes
├── deploy_parallel.sh            # Parallel deployment script ⭐
└── create_dummy_batch.sh         # Batch task to create test images
```

## Scripts Overview

### Production Scripts

**`deploy_parallel.sh`** - Main deployment script
- Detects pool size automatically
- Creates N tasks for N nodes
- Distributes files evenly across tasks
- Monitors execution and reports results

**`convert_image.py`** - Image conversion worker
- Supports `--task-id` and `--total-tasks` for parallel processing
- Uses managed identity for authentication
- Reads from input container, writes to output container

### Utility Scripts

**`create_dummy_batch.sh`** - Generate test images
```bash
./create_dummy_batch.sh <count> [prefix]
# Example: ./create_dummy_batch.sh 1000 test-image
```

## Scaling Examples

### Scale Up
```bash
# Increase to 20 nodes
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 20

# Run with 20 parallel tasks
./deploy_parallel.sh
```

### Scale Down
```bash
# Decrease to 5 nodes
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 5

# Run with 5 parallel tasks
./deploy_parallel.sh
```

### Use Low-Priority VMs (80% cheaper)
```bash
az batch pool resize \
  --pool-id image-processing-pool \
  --target-low-priority-nodes 10 \
  --target-dedicated-nodes 0
```

## Monitoring

### Check Pool Status
```bash
az batch pool show --pool-id image-processing-pool \
  --query "{Nodes:currentDedicatedNodes, Target:targetDedicatedNodes, State:allocationState}"
```

### Monitor Running Tasks
```bash
az batch task list --job-id image-conversion-job \
  --query "[?starts_with(id, 'parallel-task')].{Id:id, State:state}" -o table
```

### View Task Logs
```bash
az batch task file download \
  --job-id image-conversion-job \
  --task-id parallel-task-0 \
  --file-path stdout.txt \
  --destination ./task-0.log

cat task-0.log
```

### Check Converted Images
```bash
# Count converted images
az storage blob list \
  --account-name <storage-account> \
  --container-name converted \
  --auth-mode login \
  --query "[?ends_with(name, '.png')]" | grep -c "name"

# List recent conversions
az storage blob list \
  --account-name <storage-account> \
  --container-name converted \
  --auth-mode login \
  --query "[?ends_with(name, '.png')].{Name:name, Size:properties.contentLength, Created:properties.creationTime}" \
  -o table | head -20
```

## Troubleshooting

### Task Fails with Authentication Error
```bash
# Verify managed identity is assigned to pool
az batch pool show --pool-id image-processing-pool --query "identity"

# Verify identity has storage permissions
az role assignment list --assignee <identity-principal-id>
```

### Slow Performance
- Check VM size: Larger VMs process faster
- Monitor network bandwidth: Storage I/O can be a bottleneck
- Consider using Premium Storage for higher IOPS
- Verify nodes are in same region as storage account

### Pool Won't Scale
```bash
# Check for quota limits
az batch location quotas show --location <your-location>

# Request quota increase if needed
```

## Cost Optimization

1. **Use Low-Priority VMs**: 80% cheaper, suitable for non-urgent workloads
2. **Delete pool when not in use**: 
   ```bash
   az batch pool delete --pool-id image-processing-pool
   ```
3. **Use auto-scale formulas**:
   ```bash
   az batch pool autoscale enable \
     --pool-id image-processing-pool \
     --auto-scale-formula '$TargetDedicatedNodes = min(10, $PendingTasks.GetSample(5 * TimeInterval_Minute, 0).Count());'
   ```
4. **Choose appropriate VM sizes**: Start small and scale up as needed

## Security Best Practices

\u2705 **No secrets in code**: Uses Managed Identity
\u2705 **No SAS tokens**: Resource files use identity reference
\u2705 **RBAC-based access**: Fine-grained permissions
\u2705 **Network isolation**: Can use private endpoints
\u2705 **Audit logging**: All operations logged in Activity Log

## Cleanup

### Delete Test Images
```bash
# Delete all demo images
az storage blob delete-batch \
  --account-name <storage-account> \
  --source images \
  --auth-mode login \
  --pattern "demo-image-*.jpg"

# Delete converted images
az storage blob delete-batch \
  --account-name <storage-account> \
  --source converted \
  --auth-mode login \
  --pattern "demo-image-*.png"
```

### Scale Down Pool
```bash
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 0
```

### Delete All Resources
```bash
# Delete entire resource group (careful!)
az group delete --name <resource-group> --yes
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
  Image size: (1920, 1080), Mode: RGB
  Converted to PNG (234567 bytes)
  Uploaded as: apple.png

✓ Conversion completed successfully!
  Input:  apple.jpg
  Output: apple.png
```

## Running in Azure Batch

To use this script as an Azure Batch task:

1. Upload the script and requirements.txt to your Azure Storage
2. Create an Azure Batch pool with Python runtime
3. Configure the task to install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Set environment variables in the task configuration
5. Execute the script as the task command

## Error Handling

The script will exit with appropriate error messages if:
- Connection string is not set
- Container does not exist
- No blobs are found
- No JPG files are found
- Any conversion errors occur

## Notes

- The converted PNG file will be saved with the same name as the JPG (with .png extension)
- If a PNG file with the same name already exists, it will be overwritten
- The original JPG file is not deleted

## License

This script is provided as-is for use with Azure Batch workloads.
