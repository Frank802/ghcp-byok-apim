# Getting started

This guide walks you through standing up the BYOK proxy end to end: provisioning the
APIM gateway in front of your Microsoft Foundry deployment, then pointing a Copilot BYOK
surface at it. For background on how the pieces fit together, see the
[reference architecture](reference-architecture.md).

## What you'll end up with

- An APIM gateway that publishes an OpenAI-compatible endpoint at
  `https://<apim-name>.azure-api.net/byok`.
- A `/byok/chat/completions` operation that routes to your Foundry deployment using the
  gateway's managed identity — no Foundry keys on clients.
- A `/byok/models` operation that lists your real Foundry deployments in OpenAI
  list-models format, so Copilot's model picker only shows what you've deployed.
- A single client API key (the `byokClientKey` secret) that callers present as
  `Authorization: Bearer <client-key>`.

## Prerequisites

Before you deploy, make sure you have:

- **An Azure subscription** with permission to create resources and assign roles
  (you need `Microsoft.Authorization/roleAssignments/write`, e.g. **Owner** or
  **User Access Administrator**, because the deployment grants the gateway a role on
  Foundry).
- **An existing Microsoft Foundry / Azure OpenAI resource** with a model deployment.
  The proxy does **not** create the Foundry resource — it points at one you already have.
- **A model that meets the Copilot BYOK requirements:** tool calling (function calling),
  streaming, and ideally a context window of **≥128k tokens**. Copilot CLI errors out on
  models that lack tool calling or streaming.
- **The [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)** (with the
  Bicep tooling, which `az` installs on first use), signed in via `az login`.
- **A Copilot BYOK surface** to test with: VS Code, the Copilot CLI, or enterprise BYOK
  on GitHub.com.

> **Note:** APIM provisioning can take a while to finish (the **Developer** and
> **Premium** tiers in particular can take 30–45 minutes for the gateway to come online).
> Plan for that on the first deployment.

## Step 1 — Collect your Foundry details

From the Foundry / Azure OpenAI resource you'll be fronting, note:

| Value | Where to find it | Example |
| --- | --- | --- |
| Account name | Resource overview | `contoso-foundry` |
| Resource group | Resource overview | `rg-ai` |
| Endpoint base URL | Resource **Keys and Endpoint** | `https://contoso-foundry.openai.azure.com` |
| Deployment name | **Model deployments** blade | `gpt-4o` |

The **deployment name** (not the base model name) is what clients will pass as `model`.

## Step 2 — Clone the repo and pick a client key

```bash
git clone https://github.com/Frank802/ghcp-byok-apim.git
cd ghcp-byok-apim
```

Choose a strong secret to use as the client API key. This is the value clients will send
as their API key (`Authorization: Bearer <client-key>`); APIM validates it in policy. Generate
one however you like, for example:

```bash
openssl rand -hex 32
```

Keep this value secret — treat it like any other API key.

## Step 3 — Fill in the deployment parameters

Copy the example parameter file and edit it with your values:

```bash
cp infra/example.bicepparam infra/my.bicepparam
```

Then set each parameter in `infra/my.bicepparam`:

| Parameter | What to set it to |
| --- | --- |
| `apimName` | A globally unique name for the new APIM instance |
| `apimPublisherName` | Your team or org name (shown in the APIM portal) |
| `apimPublisherEmail` | A contact email for APIM notifications |
| `apimSkuName` / `apimSkuCapacity` | APIM tier and units (`Developer` is fine for testing) |
| `foundryAccountName` | Foundry account name from Step 1 |
| `foundryAccountResourceGroup` | Resource group that holds the Foundry account |
| `foundryBackendBaseUrl` | Foundry endpoint base URL from Step 1 |
| `foundryDeploymentName` | Foundry model deployment name from Step 1 |
| `foundryApiVersion` | Azure OpenAI API version to send to the backend |
| `foundryDeploymentsApiVersion` | Data-plane version used to list deployments for `/models` |
| `byokClientKey` | The secret you generated in Step 2 |

> **Don't commit secrets.** `byokClientKey` is a secret. Keep your filled-in
> `*.bicepparam` out of source control, or pass the key at deploy time instead of storing
> it in the file.

## Step 4 — Deploy

Create (or reuse) a resource group for the gateway, then deploy the template:

```bash
az group create --name <resource-group> --location <azure-region>

az deployment group create \
  --resource-group <resource-group> \
  --template-file infra/main.bicep \
  --parameters @infra/my.bicepparam
```

The deployment provisions the APIM instance, imports the proxy API, applies the policies,
and grants APIM's system-assigned managed identity the **`Cognitive Services OpenAI User`**
role on your Foundry account.

When it finishes, read the outputs — they give you the URLs you'll need next:

```bash
az deployment group show \
  --resource-group <resource-group> \
  --name main \
  --query properties.outputs
```

| Output | Use |
| --- | --- |
| `apimGatewayUrl` | Base gateway URL |
| `proxyBasePath` | The BYOK base URL clients point at (`.../byok`) |
| `modelsUrl` | The `/byok/models` endpoint |

## Step 5 — Verify the proxy

Use the `proxyBasePath` from the outputs as `<base-url>` and your `byokClientKey` as
`<client-key>`.

**List models** — confirms managed-identity auth and the `/models` operation:

```bash
curl "<base-url>/models" \
  -H "Authorization: ******"
```

You should get an OpenAI-style `{ "object": "list", "data": [ ... ] }` response containing
your Foundry deployment(s). Each `id` is a value you can pass as `model`.

**Send a chat completion** — confirms end-to-end routing to Foundry:

```bash
curl "<base-url>/chat/completions" \
  -H "Authorization: Bearer <client-key>" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "<your-foundry-deployment-name>",
        "messages": [{"role": "user", "content": "Say hello in one word."}]
      }'
```

A `401` means the bearer token didn't match `byokClientKey`. A `5xx` usually points at
the backend URL, deployment name, or the role assignment not having propagated yet — wait
a minute and retry.

## Step 6 — Point a Copilot surface at it

In every surface the **API key is your `byokClientKey`** and the **model is your Foundry
deployment name**. The gateway adds the backend token and `api-version`.

**VS Code (individual).** Chat view → model picker → **Manage Language Models** →
**Add Models** → **OpenAI Compatible** (or **Custom endpoint** on Insiders). Set the base
URL to `<base-url>`, the API key to your client key, and the model to your deployment name.

**Copilot CLI (individual).**

```bash
export COPILOT_PROVIDER_TYPE=openai
export COPILOT_PROVIDER_BASE_URL=<base-url>
export COPILOT_PROVIDER_API_KEY=<client-key>
export COPILOT_MODEL=<your-foundry-deployment-name>
copilot
```

**GitHub.com (enterprise).** An enterprise owner registers the proxy once under
**AI controls → Models** as an **OpenAI-compatible provider**, pointing at `<base-url>`
with the client key. The models then surface on GitHub.com, the CLI, and IDEs.

Full per-surface steps — including screenshots-worth of detail and policy toggles — are in
[client-surfaces.md](client-surfaces.md).

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `401 invalid_api_key` | ****** doesn't match `byokClientKey` | Re-check the key clients send; redeploy if you changed the secret |
| `5xx` on chat, `/models` works | Backend URL or deployment name wrong, or role not yet propagated | Verify `foundryBackendBaseUrl` + `foundryDeploymentName`; wait for the role assignment to propagate |
| `/models` returns an empty list | Wrong `foundryDeploymentsApiVersion`, or no deployments on the account | Confirm the account has deployments; adjust the data-plane API version |
| Copilot CLI errors on the model | Model lacks tool calling or streaming | Use a deployment that supports both (see [model requirements](../README.md#model-requirements)) |
| Copilot uses `azure` and hits `/openai/deployments/...` | Wrong provider type | Use the `openai` provider type targeting `/byok`, not `azure` |

## Next steps

- Harden inbound auth and require an APIM subscription key for production — see the
  [constraints and limitations](reference-architecture.md#constraints-and-limitations).
- Add backend resilience (circuit breaker, load-balanced pool) if you expect `429`s under
  load — see [backend resilience](reference-architecture.md#backend-resilience-optional).
- Review the full per-surface configuration in [client-surfaces.md](client-surfaces.md).
