targetScope = 'resourceGroup'

@description('Microsoft Foundry / Azure OpenAI account name.')
param foundryAccountName string

@description('Principal ID for the APIM managed identity.')
param apimPrincipalId string

@description('Built-in role definition ID for Azure OpenAI use.')
param roleDefinitionId string = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: foundryAccountName
}

resource apimRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundryAccount
  name: guid(foundryAccount.id, apimPrincipalId, 'cognitive-services-openai-user')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}
