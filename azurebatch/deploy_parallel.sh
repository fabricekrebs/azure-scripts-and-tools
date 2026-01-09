#!/bin/bash
# Parallel deployment script - submits 5 tasks for 5 nodes
# Each task processes a subset of JPG files

set -e

# Configuration - set these environment variables before running:
# export AZURE_SUBSCRIPTION_ID="your-subscription-id"
# export IDENTITY_RESOURCE_GROUP="your-resource-group"
# export IDENTITY_NAME="your-managed-identity-name"
# export IDENTITY_CLIENT_ID="your-client-id"

IDENTITY_RESOURCE_ID="${IDENTITY_RESOURCE_ID:-/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}}"
IDENTITY_CLIENT_ID="${IDENTITY_CLIENT_ID}"

if [ -z "$IDENTITY_CLIENT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
  echo "Error: Required environment variables not set."
  echo "Please set: AZURE_SUBSCRIPTION_ID, IDENTITY_RESOURCE_GROUP, IDENTITY_NAME, IDENTITY_CLIENT_ID"
  exit 1
fi

# Dynamically determine number of tasks based on pool size
echo "Checking pool configuration..."
TARGET_NODES=$(az batch pool show --pool-id image-processing-pool --query "targetDedicatedNodes" -o tsv)
CURRENT_NODES=$(az batch pool show --pool-id image-processing-pool --query "currentDedicatedNodes" -o tsv)

# Use target nodes (what the pool will scale to) to determine task count
NUM_TASKS=$TARGET_NODES

echo "==========================================="
echo "Azure Batch Parallel Image Conversion"
echo "Pool: $CURRENT_NODES/$TARGET_NODES nodes (current/target)"
echo "Deploying $NUM_TASKS parallel tasks"
echo "==========================================="
echo ""

if [ "$NUM_TASKS" -lt 1 ]; then
  echo "❌ Error: Pool has 0 target nodes. Cannot create tasks."
  exit 1
fi

# Upload updated script
echo "Uploading updated convert_image.py..."
az storage blob upload \
  --account-name saitalynorthbatch01 \
  --container-name scripts \
  --name convert_image.py \
  --file convert_image.py \
  --auth-mode login \
  --overwrite > /dev/null

echo "✓ Script uploaded"
echo ""

# Check pool status - already fetched above, just display
if [ "$CURRENT_NODES" -lt "$NUM_TASKS" ]; then
  echo ""
  echo "⚠️  Warning: Pool has fewer nodes than tasks"
  echo "   Tasks will be queued until nodes are available"
fi
echo ""

# Get access token
TOKEN=$(az account get-access-token --resource https://batch.core.windows.net/ --query accessToken -o tsv)
API_VERSION="2023-05-01.17.0"

# Delete existing tasks
echo "Cleaning up old tasks..."
for i in $(seq 0 $((NUM_TASKS-1))); do
  az batch task delete --job-id image-conversion-job --task-id "parallel-task-$i" --yes 2>/dev/null || true
done
echo "✓ Cleanup complete"
echo ""

# Submit parallel tasks
echo "Submitting $NUM_TASKS parallel tasks..."
for i in $(seq 0 $((NUM_TASKS-1))); do
  cat > /tmp/batch_task_$i.json <<EOF
{
  "id": "parallel-task-$i",
  "commandLine": "/bin/bash -c 'bash install_dependencies.sh && python3 convert_image.py --task-id $i --total-tasks $NUM_TASKS'",
  "environmentSettings": [
    {
      "name": "AZURE_STORAGE_ACCOUNT_NAME",
      "value": "saitalynorthbatch01"
    },
    {
      "name": "AZURE_STORAGE_INPUT_CONTAINER",
      "value": "images"
    },
    {
      "name": "AZURE_STORAGE_OUTPUT_CONTAINER",
      "value": "converted"
    },
    {
      "name": "AZURE_CLIENT_ID",
      "value": "${IDENTITY_CLIENT_ID}"
    }
  ],
  "resourceFiles": [
    {
      "httpUrl": "https://saitalynorthbatch01.blob.core.windows.net/scripts/convert_image.py",
      "filePath": "convert_image.py",
      "identityReference": {
        "resourceId": "${IDENTITY_RESOURCE_ID}"
      }
    },
    {
      "httpUrl": "https://saitalynorthbatch01.blob.core.windows.net/scripts/requirements.txt",
      "filePath": "requirements.txt",
      "identityReference": {
        "resourceId": "${IDENTITY_RESOURCE_ID}"
      }
    },
    {
      "httpUrl": "https://saitalynorthbatch01.blob.core.windows.net/scripts/install_dependencies.sh",
      "filePath": "install_dependencies.sh",
      "identityReference": {
        "resourceId": "${IDENTITY_RESOURCE_ID}"
      }
    }
  ]
}
EOF

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "https://baitalynorthbatch01.italynorth.batch.azure.com/jobs/image-conversion-job/tasks?api-version=${API_VERSION}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json; odata=minimalmetadata" \
    -d @/tmp/batch_task_$i.json)
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  
  if [ "$HTTP_CODE" == "201" ]; then
    echo "  ✓ Task $i submitted"
  else
    echo "  ✗ Task $i failed (HTTP $HTTP_CODE)"
  fi
done

echo ""
echo "==========================================="
echo "Monitoring parallel task execution"
echo "==========================================="
echo ""

# Monitor tasks
for iteration in {1..60}; do
  ELAPSED=$((iteration * 5))
  
  # Get status of all tasks
  COMPLETED=0
  RUNNING=0
  FAILED=0
  
  for i in $(seq 0 $((NUM_TASKS-1))); do
    STATE=$(az batch task show --job-id image-conversion-job --task-id "parallel-task-$i" --query "state" -o tsv 2>/dev/null || echo "unknown")
    
    case $STATE in
      "completed")
        COMPLETED=$((COMPLETED + 1))
        ;;
      "running")
        RUNNING=$((RUNNING + 1))
        ;;
      "active")
        # Active but not running yet
        ;;
      *)
        if az batch task show --job-id image-conversion-job --task-id "parallel-task-$i" --query "executionInfo.exitCode" -o tsv 2>/dev/null | grep -qv "^$"; then
          FAILED=$((FAILED + 1))
        fi
        ;;
    esac
  done
  
  echo "  [${ELAPSED}s] Completed: $COMPLETED/$NUM_TASKS | Running: $RUNNING | Failed: $FAILED"
  
  # Check if all tasks are done
  if [ "$COMPLETED" -eq "$NUM_TASKS" ]; then
    echo ""
    echo "==========================================="
    echo "✅ All tasks completed!"
    echo "==========================================="
    echo ""
    
    # Check exit codes
    ALL_SUCCESS=true
    for i in $(seq 0 $((NUM_TASKS-1))); do
      EXIT_CODE=$(az batch task show --job-id image-conversion-job --task-id "parallel-task-$i" --query "executionInfo.exitCode" -o tsv)
      if [ "$EXIT_CODE" != "0" ]; then
        ALL_SUCCESS=false
        echo "❌ Task $i failed with exit code: $EXIT_CODE"
      fi
    done
    
    if [ "$ALL_SUCCESS" = true ]; then
      echo "🎉 SUCCESS! All parallel conversions completed!"
      echo ""
      echo "Converted PNG images in 'converted' container:"
      az storage blob list \
        --account-name saitalynorthbatch01 \
        --container-name converted \
        --auth-mode login \
        --query "[?ends_with(name, '.png')].{Name:name, Size:properties.contentLength, Created:properties.creationTime}" \
        -o table | head -25
    else
      echo ""
      echo "Some tasks failed. Check logs with:"
      echo "  az batch task file download --job-id image-conversion-job --task-id parallel-task-N --file-path stdout.txt --destination ./task-N-stdout.txt"
    fi
    break
  fi
  
  sleep 5
done

echo ""
echo "Deployment complete!"
