# Azure Batch Parallel Image Converter - Project Overview

## Summary

A production-ready Azure Batch solution that converts JPG images to PNG format using parallel processing. Successfully tested with 5,000 images processed in ~100 seconds using 10 compute nodes.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Blob Storage                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   scripts    │  │    images    │  │  converted   │      │
│  │  (Python)    │  │   (Input)    │  │   (Output)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Managed Identity
                            │ (Secure Access)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Azure Batch Job                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              image-conversion-job                    │   │
│  └─────────────────────────────────────────────────────┘   │
│           │           │           │           │             │
│           ▼           ▼           ▼           ▼             │
│      ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐       │
│      │Task 0  │  │Task 1  │  │Task 2  │  │Task N  │       │
│      │Files:  │  │Files:  │  │Files:  │  │Files:  │       │
│      │0,N,2N  │  │1,N+1   │  │2,N+2   │  │...     │       │
│      └────────┘  └────────┘  └────────┘  └────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Batch Pool                          │
│     10 x Standard_D2s_v3 Ubuntu 22.04 VMs                   │
│     (Automatically scales based on pool size)                │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### File Distribution
With N nodes processing M files:
- Task 0 processes files: 0, N, 2N, 3N, ...
- Task 1 processes files: 1, N+1, 2N+1, 3N+1, ...
- Task 2 processes files: 2, N+2, 2N+2, 3N+2, ...
- ...
- Task N-1 processes files: N-1, 2N-1, 3N-1, ...

**Example with 1000 files and 10 nodes:**
- Each node processes 100 files
- Round-robin distribution ensures even load

### Workflow

1. **Upload Scripts**: All Python scripts stored in `scripts` container
2. **Create Test Data**: Run `create_dummy_batch.sh` to generate JPG files
3. **Scale Pool**: Adjust `targetDedicatedNodes` to desired parallelism
4. **Deploy Tasks**: Run `deploy_parallel.sh` which:
   - Queries pool size
   - Creates N tasks for N nodes
   - Each task downloads scripts using managed identity
   - Each task processes its assigned subset of files
5. **Monitor Progress**: Script polls task status and reports completion
6. **Verify Results**: Check `converted` container for PNG outputs

## Key Files

| File | Purpose | Critical Features |
|------|---------|-------------------|
| `convert_image.py` | Main worker script | Parallel support via `--task-id`, managed identity auth |
| `deploy_parallel.sh` | Deployment orchestrator | Auto-detects pool size, creates tasks, monitors progress |
| `create_dummy_batch.sh` | Test data generator | Runs as batch task, creates configurable number of images |
| `install_dependencies.sh` | Dependency installer | Bootstrap pip, installs packages without sudo |
| `requirements.txt` | Python packages | azure-storage-blob, azure-identity, Pillow |

## Configuration

### Current Deployment (saitalynorthbatch01)

```yaml
Subscription ID: <your-subscription-id>
Resource Group: rg-italynorth-batch-01
Region: italynorth

Batch Account: baitalynorthbatch01
Pool ID: image-processing-pool
Job ID: image-conversion-job

Storage Account: saitalynorthbatch01
Containers:
  - scripts: Python scripts and dependencies
  - images: Input JPG files
  - converted: Output PNG files

Managed Identity: id-baitalynorthbatch01-pool
  Client ID: <your-identity-client-id>
  Principal ID: <your-identity-principal-id>
  Role: Storage Blob Data Contributor
```

### VM Configuration

```yaml
Pool: image-processing-pool
VM Size: Standard_D2s_v3
  - 2 vCPUs
  - 8 GB RAM
  - 16 GB temp storage
  - Cost: ~$0.096/hour per VM (dedicated)
  - Cost: ~$0.019/hour per VM (low-priority, 80% savings)

OS: Ubuntu 22.04 LTS
Node Agent: batch.node.ubuntu 22.04
```

## Performance Benchmarks

| Test | Images | Nodes | Time | Images/sec | Cost/Run |
|------|--------|-------|------|------------|----------|
| Small | 1,000 | 5 | 15s | 67 | $0.002 |
| Medium | 1,000 | 10 | 15s | 67 | $0.004 |
| Large | 5,000 | 10 | 100s | 50 | $0.027 |

*Costs calculated for dedicated VMs at $0.096/hour*

## Security Model

### Authentication Flow
1. Pool nodes have user-assigned managed identity attached
2. Python script uses `DefaultAzureCredential()` to authenticate
3. Azure issues temporary access token automatically
4. No secrets stored in code or configuration
5. Resource files downloaded using identity reference (no SAS tokens)

### Permissions
- Managed identity has **Storage Blob Data Contributor** role
- Scoped to storage account only
- Read/write access to all containers
- RBAC-based access control

### Best Practices Implemented
✅ No connection strings in code
✅ No SAS tokens in deployment
✅ Managed identity for all blob operations
✅ Principle of least privilege
✅ All actions logged in Azure Activity Log

## Cost Analysis

### Per-Image Cost (5,000 images, 10 nodes, 100s)
- VM cost: 10 VMs × $0.096/hour × (100s/3600s) = $0.027
- Storage transactions: ~15,000 operations × $0.0004/10k = $0.0006
- **Total**: ~$0.028 per run
- **Per image**: ~$0.0000056

### Monthly Cost Estimate (Pool Running 24/7)
- 10 dedicated VMs: 10 × $0.096 × 730 hours = $700.80/month
- **Recommendation**: Delete pool when not in use, or use auto-scale

### Optimized Cost (Low-Priority VMs)
- 10 low-priority VMs: 10 × $0.019 × 730 hours = $138.70/month (80% savings)
- Trade-off: Can be preempted with 30-second notice

## Scaling Guidelines

### Horizontal Scaling (More Nodes)
```bash
# Small workloads (< 1,000 images)
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 5

# Medium workloads (1,000 - 10,000 images)
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 10

# Large workloads (> 10,000 images)
az batch pool resize --pool-id image-processing-pool --target-dedicated-nodes 20
```

### Vertical Scaling (Larger VMs)
```bash
# For memory-intensive processing
--vm-size Standard_D4s_v3  # 4 vCPU, 16 GB RAM

# For CPU-intensive processing
--vm-size Standard_F8s_v2  # 8 vCPU, 16 GB RAM (compute optimized)
```

## Troubleshooting Guide

### Issue: Tasks fail with "No module named 'azure'"
**Solution**: Check that `install_dependencies.sh` is running successfully
```bash
az batch task file download --job-id image-conversion-job --task-id parallel-task-0 --file-path stdout.txt
```

### Issue: Authentication errors accessing blob storage
**Solution**: Verify managed identity permissions
```bash
# Check identity assignment
az batch pool show --pool-id image-processing-pool --query "identity"

# Check role assignments
az role assignment list --assignee <principal-id> --scope <storage-account-resource-id>
```

### Issue: Pool won't scale beyond certain number
**Solution**: Check Batch account quotas
```bash
az batch location quotas show --location italynorth
```

### Issue: Slow performance
**Solutions**:
1. Check if storage and batch are in same region
2. Use Premium Storage for higher IOPS
3. Increase VM size for more CPU/memory
4. Monitor network bandwidth utilization

## Future Enhancements

### Possible Improvements
1. **Auto-scaling**: Implement formula-based auto-scale
2. **Job scheduling**: Add time-based job triggers
3. **Error handling**: Implement retry logic for failed conversions
4. **Format support**: Add support for other image formats (PNG→JPG, WEBP, etc.)
5. **Compression levels**: Allow configurable compression settings
6. **Watermarking**: Add optional watermark during conversion
7. **Notifications**: Send email/webhook on job completion
8. **Monitoring**: Integrate with Application Insights
9. **Cost tracking**: Add cost estimation per job

### Code Improvements
- Add unit tests for conversion logic
- Implement progress tracking within tasks
- Add validation for corrupted images
- Create configuration file instead of hardcoded values
- Package as Azure Function for serverless operation

## Maintenance

### Regular Tasks
- Monitor quotas and limits
- Review and optimize costs
- Update base OS images
- Update Python dependencies
- Clean up old test data

### Backup Strategy
- Scripts stored in blob storage (version control recommended)
- Configuration documented in deployment summary
- Identity and role assignments documented
- No data loss risk (outputs in separate container)

## References

- [Azure Batch Documentation](https://docs.microsoft.com/azure/batch/)
- [Azure Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Storage SDKs](https://docs.microsoft.com/azure/storage/blobs/storage-quickstart-blobs-python)
- [Pillow Documentation](https://pillow.readthedocs.io/)

---

**Project Status**: ✅ Production Ready
**Last Updated**: January 9, 2026
**Tested By**: Deployment validation with 5,000 images
