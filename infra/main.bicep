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

@description('Optional tags applied to deployed resources.')
param tags object = {}

var apiId = 'byok-foundry'
var openApiPath = 'openapi/byok-proxy.openapi.json'
var policyPath = 'policies/byok-proxy.xml'
var policyXml = replace(
  replace(loadTextContent(policyPath), '{{foundryDeploymentName}}', foundryDeploymentName),
  '{{foundryApiVersion}}',
  foundryApiVersion
)

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
    serviceUrl: foundryBackendBaseUrl
    format: 'openapi+json'
    value: loadTextContent(openApiPath)
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'xml'
    value: policyXml
  }
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
output backendCompletionUrl string = '${foundryBackendBaseUrl}/openai/deployments/${foundryDeploymentName}/chat/completions?api-version=${foundryApiVersion}'
