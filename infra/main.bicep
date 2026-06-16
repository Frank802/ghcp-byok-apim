targetScope = 'resourceGroup'

@description('Azure region for APIM and supporting resources.')
param location string = resourceGroup().location

@description('Name of the API Management instance.')
param apimName string

@description('APIM publisher display name.')
param apimPublisherName string = 'GHCP BYOK'

@description('APIM publisher contact email.')
param apimPublisherEmail string

@allowed([
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param apimSkuName string = 'Developer'

@minValue(1)
param apimSkuCapacity int = 1

@description('Microsoft Foundry / Azure OpenAI resource name.')
param foundryAccountName string

@description('Resource group that contains the Foundry resource.')
param foundryAccountResourceGroup string = resourceGroup().name

@description('Backend base URL, for example https://contoso.openai.azure.com.')
param foundryBackendBaseUrl string

@description('Model deployment name inside the Foundry resource.')
param foundryDeploymentName string

@description('Azure OpenAI-compatible API version to send to the backend.')
param foundryApiVersion string = '2024-06-01'

@description('Control-plane API version used to list Foundry deployments for the /models endpoint.')
param foundryDeploymentsApiVersion string = '2024-10-01'

@description('Client API key that callers must present as "Authorization: Bearer <key>". Stored as an APIM secret named value and validated in policy.')
@secure()
param byokClientKey string

@description('Optional tags applied to deployed resources.')
param tags object = {}

var apiId = 'byok-foundry'
var openApiPath = 'openapi/byok-proxy.openapi.json'
var policyPath = 'policies/byok-proxy.xml'
var modelsPolicyPath = 'policies/models.xml'
var backendId = 'foundry-backend'
var policyXml = replace(loadTextContent(policyPath), '{{foundryApiVersion}}', foundryApiVersion)
var foundryDeploymentsUrl = '${environment().resourceManager}subscriptions/${subscription().subscriptionId}/resourceGroups/${foundryAccountResourceGroup}/providers/Microsoft.CognitiveServices/accounts/${foundryAccountName}/deployments?api-version=${foundryDeploymentsApiVersion}'
var modelsPolicyXml = replace(loadTextContent(modelsPolicyPath), '{{foundryDeploymentsUrl}}', foundryDeploymentsUrl)

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSkuName
    capacity: apimSkuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: apimPublisherName
    publisherEmail: apimPublisherEmail
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: apiId
  properties: {
    displayName: 'BYOK Foundry Proxy'
    path: 'byok'
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    format: 'openapi+json'
    value: loadTextContent(openApiPath)
  }
}

resource foundryBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: backendId
  properties: {
    title: 'Microsoft Foundry'
    description: 'Foundry deployment reached with the APIM managed identity.'
    protocol: 'http'
    url: '${foundryBackendBaseUrl}/openai/deployments/${foundryDeploymentName}'
  }
}

resource byokClientKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'byokClientKey'
  properties: {
    displayName: 'byokClientKey'
    secret: true
    value: byokClientKey
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'xml'
    value: policyXml
  }
  dependsOn: [
    byokClientKeyNamedValue
    foundryBackend
  ]
}

resource listModelsOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' existing = {
  parent: api
  name: 'listModels'
}

resource listModelsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: listModelsOperation
  name: 'policy'
  properties: {
    format: 'xml'
    value: modelsPolicyXml
  }
  dependsOn: [
    byokClientKeyNamedValue
    foundryBackend
    apiPolicy
  ]
}

module foundryAccess 'modules/foundry-access.bicep' = {
  name: 'foundryAccess'
  scope: resourceGroup(foundryAccountResourceGroup)
  params: {
    foundryAccountName: foundryAccountName
    apimPrincipalId: apim.identity.principalId
  }
}

output apimGatewayUrl string = 'https://${apimName}.azure-api.net'
output proxyBasePath string = 'https://${apimName}.azure-api.net/byok'
output modelsUrl string = 'https://${apimName}.azure-api.net/byok/models'
output backendCompletionUrl string = '${foundryBackendBaseUrl}/openai/deployments/${foundryDeploymentName}/chat/completions?api-version=${foundryApiVersion}'
