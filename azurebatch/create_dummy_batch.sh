#!/bin/bash
# Deploy task to create dummy images using Azure Batch

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

# Parse arguments
NUM_IMAGES=${1:-50}
PREFIX=${2:-demo-image}

echo "==========================================="
echo "Azure Batch - Create Dummy Images"
echo "Count: $NUM_IMAGES"
echo "Prefix: $PREFIX"
echo "==========================================="
echo ""

# Upload script
echo "Uploading create_dummy_images.py..."
az storage blob upload \
  --account-name saitalynorthbatch01 \
  --container-name scripts \
  --name create_dummy_images.py \
  --file create_dummy_images.py \
  --auth-mode login \
  --overwrite > /dev/null
echo "✓ Script uploaded"
echo ""

# Create task JSON
cat > /tmp/create_images_task.json <<EOF
{
  "id": "create-dummy-images",
  "commandLine": "/bin/bash -c 'bash install_dependencies.sh && python3 create_dummy_images.py --count $NUM_IMAGES --prefix $PREFIX'",
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
      "name": "AZURE_CLIENT_ID",
      "value": "${IDENTITY_CLIENT_ID}"
    }
  ],
  "resourceFiles": [
    {
      "httpUrl": "https://saitalynorthbatch01.blob.core.windows.net/scripts/create_dummy_images.py",
      "filePath": "create_dummy_images.py",
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

# Delete existing task if it exists
echo "Cleaning up old task..."
az batch task delete --job-id image-conversion-job --task-id create-dummy-images --yes 2>/dev/null || true
echo "✓ Cleanup complete"
echo ""

# Submit task
echo "Submitting task..."
TOKEN=$(az account get-access-token --resource https://batch.core.windows.net/ --query accessToken -o tsv)
API_VERSION="2023-05-01.17.0"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://baitalynorthbatch01.italynorth.batch.azure.com/jobs/image-conversion-job/tasks?api-version=${API_VERSION}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json; odata=minimalmetadata" \
  -d @/tmp/create_images_task.json)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" == "201" ]; then
  echo "✓ Task submitted successfully"
else
  echo "✗ Task submission failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE" | head -n -1
  exit 1
fi

echo ""
echo "Monitoring task execution..."
echo ""

# Monitor task
for i in {1..60}; do
  STATE=$(az batch task show --job-id image-conversion-job --task-id create-dummy-images --query "state" -o tsv 2>/dev/null || echo "unknown")
  ELAPSED=$((i * 5))
  echo "  [${ELAPSED}s] Status: $STATE"
  
  if [ "$STATE" == "completed" ]; then
    EXIT_CODE=$(az batch task show --job-id image-conversion-job --task-id create-dummy-images --query "executionInfo.exitCode" -o tsv)
    echo ""
    echo "==========================================="
    echo "Task completed with exit code: $EXIT_CODE"
    echo "==========================================="
    echo ""
    
    if [ "$EXIT_CODE" == "0" ]; then
      echo "🎉 SUCCESS! Dummy images created!"
      echo ""
      echo "Checking created images..."
      COUNT=$(az storage blob list \
        --account-name saitalynorthbatch01 \
        --container-name images \
        --auth-mode login \
        --query "[?starts_with(name, '${PREFIX}')].name" | grep -c "name" || echo "0")
      
      echo "Total images with prefix '${PREFIX}': $COUNT"
      echo ""
      echo "Sample images:"
      az storage blob list \
        --account-name saitalynorthbatch01 \
        --container-name images \
        --auth-mode login \
        --query "[?starts_with(name, '${PREFIX}')].{Name:name, Size:properties.contentLength, Created:properties.creationTime}" \
        -o table | head -15
      
      echo ""
      echo "Ready to run parallel conversion:"
      echo "  ./deploy_parallel.sh"
    else
      echo "❌ Task failed!"
      echo ""
      echo "Fetching logs..."
      az batch task file download --job-id image-conversion-job --task-id create-dummy-images --file-path stdout.txt --destination /tmp/create-stdout.txt 2>/dev/null || true
      az batch task file download --job-id image-conversion-job --task-id create-dummy-images --file-path stderr.txt --destination /tmp/create-stderr.txt 2>/dev/null || true
      
      if [ -f /tmp/create-stdout.txt ]; then
        echo "=== STDOUT ==="
        cat /tmp/create-stdout.txt
      fi
      
      if [ -f /tmp/create-stderr.txt ]; then
        echo ""
        echo "=== STDERR ==="
        cat /tmp/create-stderr.txt
      fi
    fi
    break
  fi
  
  sleep 5
done

echo ""
echo "Done!"
