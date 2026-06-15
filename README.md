# ghcp-byok-apim

Reference architecture and Azure Bicep for a GHCP BYOK setup that fronts Microsoft Foundry model deployments with Azure API Management.

## What’s in the repo

- `docs/reference-architecture.md` — the end-to-end flow and security model
- `infra/main.bicep` — the deployable APIM + identity + access wiring
- `infra/modules/foundry-access.bicep` — the scoped role assignment for backend access
- `infra/openapi/byok-proxy.openapi.json` — the APIM import surface for chat completions
- `infra/policies/byok-proxy.xml` — the APIM policy that rewrites and authenticates requests
- `infra/example.bicepparam` — sample deployment parameters

## Deploy

```bash
az deployment group create --resource-group <resource-group> --template-file infra/main.bicep --parameters @infra/example.bicepparam
```

## Notes

- The Foundry/OpenAI resource is expected to already exist.
- APIM authenticates to the backend with managed identity and the `Cognitive Services OpenAI User` role.
- The policy forwards OpenAI-compatible chat completion calls to the Foundry deployment.
