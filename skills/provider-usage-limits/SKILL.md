---
name: provider-usage-limits
description: Use when asked about provider usage limits or credits.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [limits, quota, credits, rate-limits, openrouter, nous-portal, billing, providers]
    category: autonomous-ai-agents
    related_skills: [hermes-agent, presentation-authoring]
---

# Provider Usage Limits

Answer "what are my limits / how much have I used / why am I rate
limited" for the model providers Hermes is configured against. Limits
are per-provider and per-key, they change when the user upgrades, and
the bundled `hermes-agent` skill deliberately does not carry them —
probe live, never answer from memory.

## When to Use

- The user asks what their usage limits are, per hour/minute/day.
- The user asks about free vs paid tiers, or which tier they are on.
- A `429` or `402` needs explaining in terms of the actual cap.
- The user asks whether a plan upgrade would change anything.

## Procedure

### 1. Identify the active provider(s)

```bash
hermes config get model.provider          # e.g. openrouter
hermes auth list                          # which credentials exist
```

Both matter: `config.yaml` names the default provider, while OAuth
accounts in `auth.json` may serve a different one (the session's own
model can differ from the config default — check the runtime header of
the current session before assuming).

### 2. Probe with a zero-cost request

Never burn tokens to check limits — one token of output is enough:

```bash
curl -s -D hdr.txt -o body.json -X POST <base_url>/chat/completions \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"<model>:free","messages":[{"role":"user","content":"ping"}],"max_tokens":1}'
```

Read the rate-limit headers out of `hdr.txt` — they are the only
per-window numbers that reflect THIS key's tier, not the platform's
marketing page.

### 3. Cross-check the published tier table

Provider-specific endpoints and header names are in
`references/limits-by-provider.md`. Re-verify that file's numbers
there; prices and tiers drift.

### 4. Report a range with the assumption stated

Give requests-per-minute, per-hour, and tokens-per-minute as measured,
name the window each number belongs to, and say which tier the account
is on with the evidence (the response header that proves it). If a
window is not published, say so rather than extrapolating — an
undeclared daily cap is not "~50k requests/day".

## Pitfalls

- **Never state limits from memory.** Tier tables are re-published
  often; a stale number is worse than a fresh probe.
- **A $0 per-key limit blocks paid models even with a positive account
  balance.** OpenRouter returns `403` with `limit_source:
  "openrouter_key_limit"` while `/api/v1/credits` still shows money —
  the cap is on the KEY, not the account. Point the user at the key
  settings page, not at their balance.
- **Free models consume request quota but not credits.** A `200` with
  `credits-remaining: 0` is normal; don't read it as a balance problem.
- **Read secrets from `.env`, never print them.** Pull the key with
  `grep -oP 'OPENROUTER_API_KEY=\K.*' "$(hermes config env-path)"`
  into a shell variable and reference it as `$KEY`.
  into a shell variable and reference it as `$KEY`.
- **Token limits count input + output.** An agent turn with a large
  context exhausts TPM long before RPM — say this when the user asks
  why they hit a wall.
- **Some portals publish no usage endpoint at all.** A wall of `404`s
  on `/api/usage`, `/api/credits`, `/api/keys` is the answer, not a
  failure — headers plus the dashboard are the only visibility.
- **Report estimates as ranges** with the assumption named ("at
  135–150 wpm"), never as one precise number.

## Support files

- `references/limits-by-provider.md` — endpoints, header names, and tier tables per provider.
