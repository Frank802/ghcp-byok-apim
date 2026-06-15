# ghcp-byok-apim

Put Azure API Management in front of a Microsoft Foundry-hosted model so GitHub Copilot can use it through BYOK — without ever handing the model's credentials to the client.

Use this when you want to bring your own model to Copilot but still need to:

- **Keep backend keys out of clients.** Copilot authenticates to APIM; APIM authenticates to Foundry with managed identity. No Foundry keys in the repo, env vars, or developer machines.
- **Expose one stable endpoint.** A single OpenAI-compatible URL that works across VS Code, the Copilot CLI, and GitHub.com (enterprise BYOK).
- **Govern access centrally.** A policy layer for routing, versioning, throttling, and future request transforms — and a single place to swap or upgrade the model.
- **Deploy it repeatably.** Bicep IaC so the same gateway path stands up consistently across dev, test, and prod.

## What’s in the repo

- `docs/reference-architecture.md` — the end-to-end flow and security model
- `docs/client-surfaces.md` — where this applies (VS Code, CLI, GitHub.com) and how to configure each
- `infra/main.bicep` — the deployable APIM + identity + access wiring
- `infra/modules/foundry-access.bicep` — the scoped role assignment for backend access
- `infra/openapi/byok-proxy.openapi.json` — the APIM import surface for chat completions
- `infra/policies/byok-proxy.xml` — the APIM policy that rewrites and authenticates requests
- `infra/example.bicepparam` — sample deployment parameters

## Where this applies

The proxy is an OpenAI Chat Completions endpoint, so any Copilot BYOK surface can use it. In every case the API key is the **APIM subscription key** and the model is your **Foundry deployment name**.

| Surface | BYOK path | Provider option | Point it here |
| --- | --- | --- | --- |
| VS Code | Individual | **OpenAI Compatible** provider (or **Custom endpoint**, Insiders) | `https://<apim-name>.azure-api.net/byok` |
| Copilot CLI | Individual | `COPILOT_PROVIDER_TYPE=openai` | `https://<apim-name>.azure-api.net/byok` |
| GitHub.com (+ CLI/IDEs) | Enterprise | **OpenAI-compatible provider** under AI controls | `https://<apim-name>.azure-api.net/byok` |

Full per-surface steps are in [docs/client-surfaces.md](docs/client-surfaces.md). Note that BYOK covers chat/agent only — inline code completions always use GitHub-hosted models.

## Deploy

```bash
az deployment group create --resource-group <resource-group> --template-file infra/main.bicep --parameters @infra/example.bicepparam
```

## Connect GitHub Copilot CLI

Copilot CLI BYOK points at any OpenAI-compatible endpoint through environment variables. The APIM proxy in this repo is exposed as an OpenAI Chat Completions surface at `/byok`, so use the `openai` provider type:

```bash
export COPILOT_PROVIDER_TYPE=openai
export COPILOT_PROVIDER_BASE_URL=https://<apim-name>.azure-api.net/byok
export COPILOT_PROVIDER_API_KEY=<apim-subscription-key>
export COPILOT_MODEL=<your-foundry-deployment-name>
copilot
```

Copilot appends `/chat/completions` to the base URL, which matches the proxy operation. The gateway injects the managed-identity token and the `api-version`, so the client never handles backend credentials. See [Using your own LLM models in GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models).

## Model requirements

Per the Copilot BYOK docs, the Foundry deployment you target must:

- support **tool calling** (function calling)
- support **streaming**
- ideally provide a context window of **≥128k tokens**

If the model lacks tool calling or streaming, Copilot CLI returns an error.

## How this fits GitHub Copilot BYOK

How the project maps to the public GitHub Copilot BYOK documentation:

- **Approach is supported.** Copilot BYOK explicitly allows OpenAI-compatible endpoints, and an APIM gateway in front of Foundry is exactly that.
- **Auth model is split correctly.** The client authenticates to APIM with a key; APIM authenticates to Foundry with managed identity. Backend keys stay out of the client and the repo.
- **Provider type is `openai`, not `azure`.** With the `azure` provider type, Copilot builds the path `/openai/deployments/<deployment>/chat/completions`, which this proxy does not expose. The `openai` type targeting `/byok` is the intended fit.
- **Limitation — `responses` wire API.** Newer models use the Responses API, where Copilot calls `/responses` instead of `/chat/completions`. This proxy currently only exposes Chat Completions. Add a `/responses` operation to support those models.
- **Limitation — inbound auth.** The API is published with `subscriptionRequired: false` for first-run simplicity. For shared or production use, require an APIM subscription and validate the inbound key in policy.

## Notes

- The Foundry/OpenAI resource is expected to already exist.
- APIM authenticates to the backend with managed identity and the `Cognitive Services OpenAI User` role.
- The policy forwards OpenAI-compatible chat completion calls to the Foundry deployment.

## Docs

- [Reference architecture](docs/reference-architecture.md)
- [Where this applies — VS Code, CLI, GitHub.com](docs/client-surfaces.md)
- [GitHub Copilot CLI — Using your own LLM models (BYOK)](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models)
- [AI language models in VS Code (BYOK)](https://code.visualstudio.com/docs/agent-customization/language-models)
- [Enterprise — Using your LLM provider API keys with Copilot](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/use-your-own-api-keys)
- [GitHub Copilot SDK — BYOK auth](https://github.com/github/copilot-sdk/blob/main/docs/auth/byok.md)
- [Copilot CLI now supports BYOK and local models (changelog)](https://github.blog/changelog/2026-04-07-copilot-cli-now-supports-byok-and-local-models/)
- [Azure API Management AI gateway](https://learn.microsoft.com/en-us/azure/api-management/ai-gateway)
- [Authenticate and authorize access to LLM APIs by using Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/authenticate-authorize-azure-openai)
