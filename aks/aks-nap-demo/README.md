# AKS NAP (Node Auto Provisioning) Demo

A simple demonstration of Azure Kubernetes Service (AKS) with Node Auto Provisioning (NAP) using Karpenter for intelligent node auto-scaling.

## What is NAP?

Node Auto Provisioning (NAP) is Azure's implementation of Karpenter that automatically provisions and deprovisions nodes based on workload demands. It provides:

- **Fast Scaling**: Nodes provisioned in ~60 seconds vs traditional 3-5 minutes
- **Smart Instance Selection**: Automatic VM size selection for optimal cost/performance
- **Spot Instance Support**: Cost optimization with spot nodes when appropriate
- **Zero Configuration**: Works out-of-the-box with minimal setup

## Prerequisites

- Azure CLI 2.70.0+ installed and configured
- Azure subscription with appropriate permissions
- kubectl installed (optional, scripts will configure it)

## Quick Start

This demo consists of 4 simple scripts that demonstrate the complete NAP lifecycle:

### 1. Deploy Infrastructure
```bash
./1-deploy-infrastructure.sh
```
- Creates resource group and AKS cluster with NAP enabled using Bicep
- Automatically configures kubectl credentials
- Shows initial cluster state with NAP NodePools

### 2. Start Demo Workload
```bash
./2-start-workload.sh
```
- Deploys resource-intensive workloads (CPU and memory intensive)
- Triggers NAP to automatically provision new nodes
- Shows real-time monitoring of the scaling process

### 3. Stop Demo Workload
```bash
./3-stop-workload.sh
```
- Removes demo workloads
- Demonstrates NAP automatically removing unused nodes
- Shows the scale-down process

### 4. Cleanup Resources
```bash
./4-cleanup.sh
```
- Removes all Azure resources created by the demo
- Includes safety confirmation prompt

## What You'll See

### During Scale-Up (Script 2):
1. **Initial State**: 2 system nodes (Standard_DS2_v2)
2. **Workload Deployment**: High-resource pods that don't fit on existing nodes
3. **NAP Activity**: Automatic creation of NodeClaims
4. **Node Provisioning**: New nodes (typically Standard_D8als_v6 or similar) added automatically
5. **Pod Scheduling**: Pending pods scheduled on new nodes

### During Scale-Down (Script 3):
1. **Workload Removal**: Demo pods deleted
2. **Node Evaluation**: NAP evaluates which nodes are no longer needed
3. **Graceful Drain**: Unused nodes are drained safely
4. **Node Removal**: Empty nodes are automatically terminated

## Key NAP Benefits Demonstrated

✅ **Zero Manual Intervention** - No need to predict or configure node scaling  
✅ **Intelligent Instance Selection** - Right-sized VMs for specific workloads  
✅ **Fast Response Time** - Rapid scaling compared to traditional autoscaling  
✅ **Cost Optimization** - Automatic scale-down when resources aren't needed  
✅ **Seamless Integration** - Works transparently with Kubernetes scheduler  

## Infrastructure Details

The demo creates:
- **AKS Cluster**: Kubernetes 1.31 with NAP enabled
- **Virtual Network**: Dedicated VNet with Azure CNI
- **Log Analytics**: For monitoring and observability
- **System Node Pool**: 2 nodes for system workloads
- **NAP Node Pools**: Automatic scaling for application workloads

## Files Structure

```
aks-nap-demo/
├── 1-deploy-infrastructure.sh    # Deploy AKS cluster with NAP
├── 2-start-workload.sh          # Deploy demo workloads
├── 3-stop-workload.sh           # Remove workloads and observe scale-down
├── 4-cleanup.sh                 # Clean up all resources
├── main.bicep                   # Infrastructure as Code template
├── dev.bicepparam               # Development environment parameters
└── README.md                    # This file
```

## Monitoring Commands

While the demo is running, you can monitor NAP activity with:

```bash
# Watch overall cluster state
watch 'kubectl get nodes && echo && kubectl get nodeclaim && echo && kubectl get pods -n nap-demo'

# Check NAP NodePools
kubectl get nodepool

# View cluster events
kubectl get events --sort-by='.lastTimestamp'

# Monitor resource utilization
kubectl top nodes
```

## Troubleshooting

### Common Issues:
1. **Azure CLI version**: Ensure you have Azure CLI 2.70.0+
2. **Permissions**: Verify you have Contributor access to the subscription
3. **Regional availability**: NAP is available in most Azure regions
4. **Quota limits**: Ensure sufficient VM quota in your subscription

### Getting Help:
- Check Azure CLI version: `az version`
- Verify login: `az account show`
- Check cluster status: `az aks show --resource-group rg-italynorth-aksnapdemo-01 --name aks-nap-demo`

## Cost Considerations

- System nodes run continuously (~$100-200/month for 2 DS2_v2 nodes)
- NAP nodes are created on-demand and scale to zero
- Demo workloads run for short periods during testing
- Always run `./4-cleanup.sh` when finished to avoid ongoing charges

## Next Steps

After completing the demo:
1. Explore NAP NodePool configurations
2. Test with different workload types and resource requirements
3. Experiment with spot instances and mixed instance types
4. Integrate NAP into your production workloads

For more information about NAP, visit the [Azure documentation](https://docs.microsoft.com/en-us/azure/aks/).