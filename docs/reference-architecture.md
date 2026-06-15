# Reference architecture

```mermaid
flowchart LR
  subgraph Clients["Copilot BYOK surfaces"]
    VSCODE[VS Code]
    CLI[Copilot CLI]
    WEB[GitHub.com / Enterprise BYOK]
  end
  Clients --> APIM[Azure API Management]
  APIM --> MI[Managed identity token]
  APIM --> FOUNDRY[Microsoft Foundry / Azure OpenAI-compatible endpoint]
  FOUNDRY --> MODEL[Hosted model deployment]
```

## Design

Any Copilot BYOK surface — VS Code, the Copilot CLI, or GitHub.com (enterprise BYOK) —
talks only to APIM as an OpenAI Chat Completions endpoint. APIM:

- authenticates to the backend with managed identity
- rewrites the request to the Foundry deployment path
- appends the required `api-version`
- preserves the OpenAI-compatible payload shape

The Foundry resource is treated as the model host. This keeps model access centralized, auditable, and easy to swap without changing the client contract. Because the contract is identical across surfaces, the same gateway serves individual (VS Code, CLI) and enterprise (GitHub.com) BYOK paths without change.

## Security model

- No API keys are stored in the repo.
- APIM uses Microsoft Entra ID managed identity for backend auth.
- The managed identity gets the `Cognitive Services OpenAI User` role on the Foundry resource.
- The backend URL and deployment name are parameterized so the same template works across environments.

## Repo shape

- `infra/main.bicep` provisions the gateway and access path.
- `infra/openapi/byok-proxy.openapi.json` defines the APIM-imported proxy API.
- `infra/policies/byok-proxy.xml` contains the request rewrite and auth logic.

## Runtime flow

1. A Copilot BYOK surface (VS Code, CLI, or GitHub.com) sends an OpenAI-compatible chat request to APIM.
2. APIM acquires an Entra token with managed identity.
3. APIM rewrites the path to the Foundry deployment endpoint.
4. Foundry returns the model response through APIM.

## Client configuration

This proxy is published as an OpenAI Chat Completions endpoint, so it plugs into every
Copilot BYOK surface. In all cases the API key is the **APIM subscription key** and the
model is your **Foundry deployment name**; the gateway adds the backend token and `api-version`.

- **VS Code (individual).** Manage Language Models → **OpenAI Compatible** provider (or **Custom endpoint** on Insiders), base URL `https://<apim-name>.azure-api.net/byok`.
- **Copilot CLI (individual).** Environment variables with the `openai` provider type:

  ```bash
  export COPILOT_PROVIDER_TYPE=openai
  export COPILOT_PROVIDER_BASE_URL=https://<apim-name>.azure-api.net/byok
  export COPILOT_PROVIDER_API_KEY=<apim-subscription-key>
  export COPILOT_MODEL=<your-foundry-deployment-name>
  ```

  Copilot appends `/chat/completions` to the base URL, matching the proxy operation.
- **GitHub.com (enterprise).** An enterprise owner registers the proxy once as an **OpenAI-compatible provider** under AI controls; the models then surface on GitHub.com, the CLI, and IDEs under the enterprise name.

Full per-surface steps are in [client-surfaces.md](client-surfaces.md).

## Constraints and limitations

- **Surface scope.** BYOK applies to chat, agent, and utility tasks only. Inline code completions always use GitHub-hosted models, regardless of surface.
- **Model capabilities.** The Foundry deployment must support tool calling and streaming; a context window of ≥128k tokens is recommended.
- **Provider type.** The proxy targets the `openai` / OpenAI-compatible provider at `/byok`. The `azure` provider type expects a `/openai/deployments/<deployment>/chat/completions` path that this proxy does not expose.
- **Wire API.** Only the Chat Completions wire API is proxied. Models that use the Responses API (Copilot calls `/responses`) need an additional operation. Enterprise BYOK also requires chat/Completions-style APIs.
- **Inbound auth.** The sample API sets `subscriptionRequired: false`. Production deployments should require an APIM subscription key and validate it in the inbound policy.
- **Enterprise BYOK is public preview** and subject to change.
