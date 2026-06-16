# ghcp-byok-apim

Put Azure API Management in front of a Microsoft Foundry-hosted model so GitHub Copilot can use it through BYOK.

Use this when you want to bring your own model to Copilot but still need to:

- **Keep backend keys out of clients.** Copilot authenticates to APIM; APIM authenticates to Foundry with managed identity. No Foundry keys in the repo, env vars, or developer machines.
- **Expose one stable endpoint.** A single OpenAI-compatible URL that works across VS Code, the Copilot CLI, and GitHub.com (enterprise BYOK).
- **Govern access centrally.** A policy layer for routing, versioning, throttling, and future request transforms — and a single place to swap or upgrade the model.
- **Stay resilient under load (optional).** Foundry is reached through a named APIM backend entity, so you can opt into a circuit breaker that backs off on `429 Too Many Requests` and honors `Retry-After` — and combine it with a load-balanced pool to spread traffic across multiple Foundry deployments. Neither is enabled by default.
- **Deploy it repeatably.** Bicep IaC so the same gateway path stands up consistently across dev, test, and prod.

Check out the [reference architecture](docs/reference-architecture.md) for more details on how the pieces fit together.

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
- **Inbound auth.** OpenAI-compatible clients send the key as `Authorization: Bearer <key>`, which APIM's built-in subscription check never sees (it only reads `Ocp-Apim-Subscription-Key`/`subscription-key`, and that check runs before policy). So the API keeps `subscriptionRequired: false` and the inbound policy instead extracts the bearer token and validates it against the `byokClientKey` secret named value, returning 401 on mismatch. Set `byokClientKey` to a strong secret and hand that value to clients as their API key.

## Notes

- The Foundry/OpenAI resource is expected to already exist.
- APIM reaches Foundry through a named **backend entity** (`foundry-backend`) and authenticates with its system-assigned managed identity, which holds the `Cognitive Services OpenAI User` role.
- The policy validates the client key, attaches the managed-identity token, and routes OpenAI-compatible chat completion calls to the backend entity.
- **Optional resilience.** The circuit breaker and load-balanced pool are opt-in and not part of the default deployment; enable them only if you need 429 back-off or multi-deployment fan-out.
- **Enterprise BYOK is public preview** and subject to change.

## Useful docs

- [AI language models in VS Code (BYOK)](https://code.visualstudio.com/docs/agent-customization/language-models#_bring-your-own-language-model-key)
- [GitHub Copilot CLI — Using your own LLM models (BYOK)](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models)
- [Enterprise — Using your LLM provider API keys with Copilot](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/use-your-own-api-keys)
- [Azure API Management AI gateway](https://learn.microsoft.com/en-us/azure/api-management/genai-gateway-capabilities)
- [Import a Microsoft Foundry API](https://learn.microsoft.com/en-us/azure/api-management/azure-ai-foundry-api)
- [Circuit Breaker in API Management](https://learn.microsoft.com/en-us/azure/api-management/backends?tabs=portal#circuit-breaker)
- [Load Balanced Pool in API Management](https://learn.microsoft.com/en-us/azure/api-management/backends?tabs=portal#load-balanced-pool)
