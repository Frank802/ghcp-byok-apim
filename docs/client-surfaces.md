# Where this configuration applies

The APIM proxy in this repo is published as an OpenAI **Chat Completions** endpoint at
`https://<apim-name>.azure-api.net/byok`. Any Copilot surface that supports a
BYOK / OpenAI-compatible provider can point at it. If you haven't deployed the gateway
yet, follow the [getting started guide](getting-started.md) first.

There are two distinct BYOK paths:

- **Individual BYOK** — a single user adds the endpoint in VS Code or the CLI. Per-user, no admin required.
- **Enterprise BYOK** — an enterprise admin registers the endpoint once on GitHub.com; the models then appear for the whole org across GitHub.com, the CLI, and IDEs. (Public preview.)

> **Intended scenario.** This gateway uses a **single, shared endpoint and credential** and is designed primarily for the **Enterprise BYOK** path — one centralized configuration for the whole org. Access is centralized behind one credential, so it does **not** identify individual users (e.g., for per-user chargeback). The individual surfaces below can use the same endpoint for development and testing.

## Summary

| Surface | BYOK path | Provider option | Point it here |
| --- | --- | --- | --- |
| VS Code | Individual | **OpenAI Compatible** built-in provider, or **Custom endpoint** (Insiders) | `https://<apim-name>.azure-api.net/byok` |
| Copilot CLI | Individual | `COPILOT_PROVIDER_TYPE=openai` | `https://<apim-name>.azure-api.net/byok` |
| GitHub.com (+ CLI/IDEs) | Enterprise | **OpenAI-compatible provider** under AI controls | `https://<apim-name>.azure-api.net/byok` |

In every case the API key is the **APIM subscription key**, and the model identifier is
your **Foundry deployment name**. The gateway adds the backend token and `api-version`.

## VS Code

1. Open the Chat view, open the model picker, and select **Manage Language Models** (or run **Chat: Manage Language Models**).
2. Select **Add Models**, then choose **OpenAI Compatible**. (On VS Code Insiders you can instead choose **Custom endpoint**, which also speaks Chat Completions.)
3. Configure:
   - Base URL / endpoint: `https://<apim-name>.azure-api.net/byok`
   - API key: your APIM subscription key
   - Model: your Foundry deployment name
4. Select the model from the model picker.

BYOK in VS Code applies to **chat and agent** features only. Inline code completions and
embeddings still use GitHub-hosted models.

See [AI language models in VS Code](https://code.visualstudio.com/docs/agent-customization/language-models).

## Copilot CLI

```bash
export COPILOT_PROVIDER_TYPE=openai
export COPILOT_PROVIDER_BASE_URL=https://<apim-name>.azure-api.net/byok
export COPILOT_PROVIDER_API_KEY=<apim-subscription-key>
export COPILOT_MODEL=<your-foundry-deployment-name>
copilot
```

Copilot appends `/chat/completions` to the base URL, which matches the proxy operation.

See [Using your own LLM models in GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models).

## GitHub.com (enterprise only)

An enterprise owner registers the proxy once, and the models become available in Copilot
Chat on GitHub.com as well as in the CLI and IDEs, listed under the enterprise name.

1. On GitHub.com, go to your enterprise, then **AI controls** → **Models**.
2. Add a key for an **OpenAI-compatible provider**, pointing at `https://<apim-name>.azure-api.net/byok` with the APIM subscription key.
3. Select the model(s) to expose, identified by the Foundry deployment name.
4. For IDE use, ensure the **Bring Your Own Language Model Key in VS Code** policy is enabled in the [Copilot policy settings](https://github.com/settings/copilot/features).

Supported enterprise providers include Anthropic, AWS Bedrock, Google AI Studio,
Microsoft Foundry, OpenAI, **OpenAI-compatible providers**, and xAI — this proxy
registers as an OpenAI-compatible provider.

See [Using your LLM provider API keys with Copilot](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/use-your-own-api-keys).

## Cross-surface caveats

- **Completions are never BYOK.** Inline code completions always use GitHub-hosted models. BYOK covers chat, agent, and utility tasks.
- **Chat Completions only.** This proxy exposes the Chat Completions wire API. Models that require the Responses API (Copilot calls `/responses`) need an additional operation. Enterprise BYOK also requires chat/Completions-style APIs.
- **Enterprise BYOK is public preview** and subject to change.
- **Use a least-privilege key.** Here that is a scoped APIM subscription key, not a backend Foundry key.
