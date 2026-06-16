using './main.bicep'

param apimName = 'ghcp-byok-apim-dev'
param apimPublisherName = 'GHCP BYOK'
param apimPublisherEmail = 'your-email@example.com'
param apimSkuName = 'Developer'
param apimSkuCapacity = 1
param foundryAccountName = 'your-foundry-account'
param foundryAccountResourceGroup = 'your-foundry-resource-group'
param foundryBackendBaseUrl = 'https://your-foundry-account.openai.azure.com'
param foundryDeploymentName = 'your-model-deployment'
param foundryApiVersion = '2024-06-01'
param byokClientKey = 'replace-with-a-strong-secret-key'
