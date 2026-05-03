<# 
Creates the Azure resources used by the Enterprise API project.

Prerequisites:
- Azure CLI installed
- Docker installed if you want to build/push images later
- Permissions to create resources, role assignments, App Registrations, and federated credentials

Before running:
1. Replace $GITHUB_ORG with your GitHub user or organization.
2. Make sure the resource names are available globally where required.
3. Run from PowerShell:
   .\scripts\create-azure-resources.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Azure subscription and target region.
$SUBSCRIPTION_ID = "6b6a9c6b-f4db-4532-a846-1fcfcf6e4b3f"
$LOCATION = "francecentral"

# Existing Resource Group used during the manual setup.
$RG = "RG-Taoufik-Mellah"

# Resource names.
$ACR_NAME = "acrenterpriseapi001"
$PLAN_NAME = "asp-enterprise-api-prod"
$APP_NAME = "app-enterprise-api-prod"
$SLOT_NAME = "green"
$KV_NAME = "kv-entapi-tm-prod"
$LAW_NAME = "law-enterprise-api-prod"
$APPINSIGHTS_NAME = "appi-enterprise-api-prod"

# GitHub OIDC configuration.
$APP_REG_NAME = "github-enterprise-api-prod"
$GITHUB_ORG = "ton-user-ou-organisation"
$GITHUB_REPO = "enterprise-api-cicd"

# Secret used for the training/demo environment.
$SECRET_NAME = "ApiSecret"
$SECRET_VALUE = "super-secret-prod-value"

Write-Host "Setting Azure subscription..."
az account set --subscription $SUBSCRIPTION_ID

Write-Host "Checking Resource Group..."
az group show --name $RG --output table

Write-Host "Creating Azure Container Registry..."
az acr create `
  --resource-group $RG `
  --name $ACR_NAME `
  --sku Basic `
  --admin-enabled true

Write-Host "Creating Linux App Service Plan..."
az appservice plan create `
  --name $PLAN_NAME `
  --resource-group $RG `
  --location $LOCATION `
  --is-linux `
  --sku P1v3

Write-Host "Creating App Service container with nginx placeholder image..."
az webapp create `
  --resource-group $RG `
  --plan $PLAN_NAME `
  --name $APP_NAME `
  --deployment-container-image-name nginx:latest

Write-Host "Creating green deployment slot..."
az webapp deployment slot create `
  --resource-group $RG `
  --name $APP_NAME `
  --slot $SLOT_NAME

Write-Host "Enabling Always On for production..."
az webapp config set `
  --resource-group $RG `
  --name $APP_NAME `
  --always-on true

Write-Host "Enabling Always On for green slot..."
az webapp config set `
  --resource-group $RG `
  --name $APP_NAME `
  --slot $SLOT_NAME `
  --always-on true

Write-Host "Creating Key Vault..."
az keyvault create `
  --name $KV_NAME `
  --resource-group $RG `
  --location $LOCATION

Write-Host "Granting current user permission to manage Key Vault secrets..."
$USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv
$KV_ID = az keyvault show --name $KV_NAME --query id -o tsv

az role assignment create `
  --assignee-object-id $USER_OBJECT_ID `
  --assignee-principal-type User `
  --role "Key Vault Secrets Officer" `
  --scope $KV_ID

Write-Host "Waiting 90 seconds for Key Vault RBAC propagation..."
Start-Sleep -Seconds 90

Write-Host "Creating Key Vault secret..."
az keyvault secret set `
  --vault-name $KV_NAME `
  --name $SECRET_NAME `
  --value $SECRET_VALUE

Write-Host "Creating Log Analytics Workspace..."
az monitor log-analytics workspace create `
  --resource-group $RG `
  --workspace-name $LAW_NAME `
  --location $LOCATION

Write-Host "Creating Application Insights linked to Log Analytics..."
az monitor app-insights component create `
  --app $APPINSIGHTS_NAME `
  --location $LOCATION `
  --resource-group $RG `
  --workspace $LAW_NAME `
  --application-type web

Write-Host "Assigning Managed Identity to App Service..."
az webapp identity assign `
  --resource-group $RG `
  --name $APP_NAME

Write-Host "Granting App Service access to Key Vault secrets..."
$APP_IDENTITY_ID = az webapp identity show --resource-group $RG --name $APP_NAME --query principalId -o tsv
$KV_ID = az keyvault show --name $KV_NAME --query id -o tsv

az role assignment create `
  --assignee-object-id $APP_IDENTITY_ID `
  --assignee-principal-type ServicePrincipal `
  --role "Key Vault Secrets User" `
  --scope $KV_ID

Write-Host "Granting App Service AcrPull access..."
$ACR_ID = az acr show --name $ACR_NAME --resource-group $RG --query id -o tsv

az role assignment create `
  --assignee-object-id $APP_IDENTITY_ID `
  --assignee-principal-type ServicePrincipal `
  --role AcrPull `
  --scope $ACR_ID

Write-Host "Injecting Key Vault reference and environment into App Service settings..."
$SECRET_URI = az keyvault secret show --vault-name $KV_NAME --name $SECRET_NAME --query id -o tsv

az webapp config appsettings set `
  --resource-group $RG `
  --name $APP_NAME `
  --settings ASPNETCORE_ENVIRONMENT=Production ApiSecret="@Microsoft.KeyVault(SecretUri=$SECRET_URI)"

Write-Host "Injecting Key Vault reference and environment into green slot settings..."
az webapp config appsettings set `
  --resource-group $RG `
  --name $APP_NAME `
  --slot $SLOT_NAME `
  --settings ASPNETCORE_ENVIRONMENT=Production ApiSecret="@Microsoft.KeyVault(SecretUri=$SECRET_URI)"

Write-Host "Creating App Registration for GitHub Actions OIDC..."
$APP_ID = az ad app create `
  --display-name $APP_REG_NAME `
  --query appId `
  -o tsv

Write-Host "Creating Service Principal for App Registration..."
az ad sp create --id $APP_ID

Write-Host "Granting GitHub Actions Contributor access on Resource Group..."
az role assignment create `
  --assignee $APP_ID `
  --role Contributor `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"

Write-Host "Granting GitHub Actions AcrPush access on ACR..."
az role assignment create `
  --assignee $APP_ID `
  --role AcrPush `
  --scope $ACR_ID

Write-Host "Creating GitHub OIDC federated credential for main branch..."
$FEDERATED_CREDENTIAL_FILE = Join-Path $PSScriptRoot "federated-credential-main.json"

@"
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/main",
  "description": "GitHub Actions main branch",
  "audiences": ["api://AzureADTokenExchange"]
}
"@ | Out-File -FilePath $FEDERATED_CREDENTIAL_FILE -Encoding utf8

az ad app federated-credential create `
  --id $APP_ID `
  --parameters $FEDERATED_CREDENTIAL_FILE

Write-Host ""
Write-Host "Azure resources created successfully."
Write-Host ""
Write-Host "Add these GitHub repository variables:"
Write-Host "AZURE_CLIENT_ID=$APP_ID"
Write-Host "AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"
Write-Host "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
Write-Host "ACR_NAME=$ACR_NAME"
Write-Host "ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)"
Write-Host ""
