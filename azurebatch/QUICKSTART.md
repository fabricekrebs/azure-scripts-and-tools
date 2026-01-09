# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Prerequisites
- Azure subscription
- Azure CLI installed and logged in

### Step 1: Clone/Download This Project
```bash
cd /path/to/your/workspace
# All files should be in this directory
```

### Step 2: Set Your Configuration
Edit `deploy_parallel.sh` and update:
```bash
IDENTITY_RESOURCE_ID="<your-managed-identity-resource-id>"
IDENTITY_CLIENT_ID="<your-managed-identity-client-id>"
```

Replace storage account name throughout the script:
```bash
# Find and replace 'saitalynorthbatch01' with your storage account name
sed -i 's/saitalynorthbatch01/YOUR_STORAGE_ACCOUNT/g' *.sh
```

### Step 3: Upload Scripts to Azure Storage
```bash
STORAGE_ACCOUNT="your-storage-account-name"

az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name convert_image.py --file convert_image.py --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name requirements.txt --file requirements.txt --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name install_dependencies.sh --file install_dependencies.sh --auth-mode login --overwrite
az storage blob upload --account-name $STORAGE_ACCOUNT --container-name scripts --name create_dummy_images.py --file create_dummy_images.py --auth-mode login --overwrite
```

### Step 4: Create Test Images
```bash
./create_dummy_batch.sh 100 test-image
# This will create 100 test JPG files in your 'images' container
```

### Step 5: Scale Your Pool
```bash
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 5

# Wait for nodes to be ready (takes 3-5 minutes)
watch -n 5 'az batch pool show --pool-id image-processing-pool --query "{Current:currentDedicatedNodes, Target:targetDedicatedNodes, State:allocationState}"'
```

### Step 6: Run Parallel Conversion
```bash
./deploy_parallel.sh
```

Expected output:
```
===========================================
Azure Batch Parallel Image Conversion
Pool: 5/5 nodes (current/target)
Deploying 5 parallel tasks
===========================================

✓ Script uploaded
✓ Cleanup complete

Submitting 5 parallel tasks...
  ✓ Task 0 submitted
  ✓ Task 1 submitted
  ...

[15s] Completed: 5/5 | Running: 0 | Failed: 0

🎉 SUCCESS! All parallel conversions completed!
```

### Step 7: Verify Results
```bash
# Count converted files
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name converted \
  --auth-mode login \
  --query "[?ends_with(name, '.png')]" | grep -c "name"

# Should show: 100
```

## 🎯 Next Steps

### Scale to 1000 Images
```bash
./create_dummy_batch.sh 1000 demo-image
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 10
./deploy_parallel.sh
```

### Monitor Performance
```bash
# Watch task progress in real-time
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

## 📊 Performance Expectations

| Images | Nodes | Expected Time |
|--------|-------|---------------|
| 100    | 5     | ~10 seconds   |
| 1,000  | 10    | ~15 seconds   |
| 5,000  | 10    | ~100 seconds  |
| 10,000 | 20    | ~120 seconds  |

## 🧹 Cleanup

### Delete Test Images
```bash
# Delete input images
az storage blob delete-batch \
  --account-name $STORAGE_ACCOUNT \
  --source images \
  --auth-mode login \
  --pattern "test-image-*.jpg"

# Delete output images
az storage blob delete-batch \
  --account-name $STORAGE_ACCOUNT \
  --source converted \
  --auth-mode login \
  --pattern "test-image-*.png"
```

### Scale Down Pool (Save Costs)
```bash
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 0
```

## ❓ Troubleshooting

### Issue: "Container does not exist"
```bash
# Create missing containers
az storage container create --name images --account-name $STORAGE_ACCOUNT --auth-mode login
az storage container create --name converted --account-name $STORAGE_ACCOUNT --auth-mode login
az storage container create --name scripts --account-name $STORAGE_ACCOUNT --auth-mode login
```

### Issue: "Authentication failed"
```bash
# Verify managed identity is configured
az batch pool show --pool-id image-processing-pool --query "identity"

# Verify identity has permissions
az role assignment list --assignee <principal-id>
```

### Issue: "No module named 'azure'"
Check task logs to ensure install_dependencies.sh ran successfully:
```bash
az batch task file download \
  --job-id image-conversion-job \
  --task-id parallel-task-0 \
  --file-path stdout.txt
```

## 📚 More Information

- **Full Documentation**: See [README.md](README.md)
- **Deployment Details**: See [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)
- **Architecture**: See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)

## 💡 Tips

1. **Start Small**: Test with 100 images first
2. **Scale Gradually**: Increase nodes as needed
3. **Monitor Costs**: Delete pool when not in use
4. **Use Low-Priority VMs**: 80% cost savings for non-urgent work
5. **Same Region**: Ensure Batch and Storage are in same region for best performance

---

**Happy Processing! 🚀**
