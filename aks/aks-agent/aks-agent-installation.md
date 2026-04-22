# AKS Agent Deployment Steps

Step-by-step guide to deploy an AKS agent with Azure Workload Identity and Azure OpenAI access.

## Prerequisites

- Azure CLI (`az`) installed and logged in
- `kubectl` configured to target the AKS cluster
- AKS cluster with **OIDC Issuer** and **Workload Identity** enabled

---

## 1. Set Environment Variables

Define the cluster, identity, and OpenAI resource configuration.

```bash
export RESOURCE_GROUP="rg-italynorth-aks-01"
export CLUSTER_NAME="aks-italynorth-01"
export LOCATION="italynorth"
export USER_ASSIGNED_IDENTITY_NAME="id-aks-agent"
export OPENAI_RESOURCE_NAME="af-francecentral-foundry-01"
export OPENAI_RESOURCE_GROUP="rg-francecentral-foundry-01"
export SUBSCRIPTION="$(az account show --query id --output tsv)"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="aks-agent-federated-credential"
```

Service account details used for workload identity binding:

```bash
export SERVICE_ACCOUNT_NAME="aks-agent"
export SERVICE_ACCOUNT_NAMESPACE="aks-agent"
```

---

## 2. Create Namespace and Service Account

Create a dedicated namespace and Kubernetes service account for the agent.

```bash
kubectl create namespace "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
```

---

## 3. Grant Cluster-Wide Read Access

Bind the `view` ClusterRole to the service account, giving it read-only access to most namespaced resources across the cluster.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aks-agent-view-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF
```

Verify the service account and role binding were created:

```bash
kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl get clusterrolebinding aks-agent-view-rolebinding
```

---

## 4. Verify Workload Identity and Retrieve OIDC Issuer

Confirm that workload identity is enabled on the cluster:

```bash
az aks show --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" \
    --query "securityProfile.workloadIdentity.enabled"
```

Retrieve the OIDC issuer URL (required for federated credential setup):

```bash
export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "oidcIssuerProfile.issuerUrl" --output tsv)"
```

---

## 5. Create the User-Assigned Managed Identity

This identity will be used by the agent pod via workload identity federation.

```bash
az identity create \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --subscription "${SUBSCRIPTION}"
```

Retrieve the managed identity's client ID:

```bash
export USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query 'clientId' --output tsv)"
```

---

## 6. Assign Azure RBAC Roles

Grant **Reader** access at the subscription level so the agent can enumerate resources:

```bash
az role assignment create \
    --role "Reader" \
    --assignee "${USER_ASSIGNED_CLIENT_ID}" \
    --scope "/subscriptions/${SUBSCRIPTION}"
```

Grant **Cognitive Services User** on the Azure OpenAI resource for model inference:

```bash
az role assignment create \
    --role "Cognitive Services User" \
    --assignee "${USER_ASSIGNED_CLIENT_ID}" \
    --scope "/subscriptions/${SUBSCRIPTION}/resourceGroups/${OPENAI_RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${OPENAI_RESOURCE_NAME}"
```

Grant **Azure AI User** on the same resource for additional AI Foundry operations:

```bash
az role assignment create \
    --role "Azure AI User" \
    --assignee "${USER_ASSIGNED_CLIENT_ID}" \
    --scope "/subscriptions/${SUBSCRIPTION}/resourceGroups/${OPENAI_RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${OPENAI_RESOURCE_NAME}"
```

---

## 7. Annotate the Service Account for Workload Identity

Link the Kubernetes service account to the managed identity by setting the client ID annotation:

```bash
kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    --namespace "${SERVICE_ACCOUNT_NAMESPACE}" \
    azure.workload.identity/client-id="${USER_ASSIGNED_CLIENT_ID}" \
    --overwrite
```

Verify the annotation was applied:

```bash
kubectl describe serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
```

---

## 8. Create the Federated Identity Credential

Establish the trust relationship between the Kubernetes service account and the Azure managed identity via OIDC federation:

```bash
az identity federated-credential create \
    --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
    --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --issuer "${AKS_OIDC_ISSUER}" \
    --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" \
    --audience api://AzureADTokenExchange
```

Verify the federated credential was created:

```bash
az identity federated-credential list \
    --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}"
```

---

## 9. Initialize the AKS Agent

Deploy the agent into the cluster:

```bash
az aks agent-init \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}"
```


## 10. Test the AKS Agent

Test the agent from the aks cli:
```bash
az aks agent "How many nodes do I have in my cluster?" --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --namespace aks-agent
```