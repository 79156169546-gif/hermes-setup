# Limits by provider

Endpoints, header names, and tier tables. **Prices and tiers drift —
re-probe before quoting any number here.**

## Nous Portal (`inference-api.nousresearch.com/v1`)

Auth: OAuth device code (`hermes auth add nous`); token in
`~/AppData/Local/hermes/auth.json` under `providers.nous.access_token`,
~1 h lifetime, auto-refreshed.

### Published tier table

Source: `GET https://portal.nousresearch.com/api/openapi` →
`info.description` → "API Key Rate Limits".

| Tier | RPM | TPM | Price | Monthly credits | Rollover cap |
|---|---|---|---|---|---|
| Free | 50 | 500 000 | $0 | $0 (free models only) | — |
| Default paid (no plan) | 180 | 720 000 | pay-as-you-go | top-up | — |
| Plus | 400 | 4 000 000 | $20/mo | $22 (+10%) | $10 |
| Super | 800 | 8 000 000 | $100/mo | $110 (+10%) | $50 |
| Ultra | 1600 | 16 000 000 | $200/mo | $220 (+10%) | $100 |

### Response headers (the live truth)

```
x-ratelimit-limit-requests: 50          x-ratelimit-remaining-requests: 43
x-ratelimit-limit-requests-1h: 2100     x-ratelimit-remaining-requests-1h: 2072
x-ratelimit-limit-tokens: 500000        x-ratelimit-remaining-tokens: 499986
x-ratelimit-limit-tokens-1h: 6000000    x-ratelimit-remaining-tokens-1h: 5989998
x-ratelimit-reset-requests: 0.899       x-ratelimit-reset-requests-1h: 3012.899
x-ratelimit-reset-tokens: 59.999        x-ratelimit-reset-tokens-1h: 3011.799
x-nous-credits-paid-access: false
x-nous-credits-remaining-usd: 0.00
x-nous-credits-subscription-usd: 0.00
x-nous-credits-disabled-reason: out_of_credits
x-nous-tool-pool-gated-off: false
```

- Only two windows are published: **1 minute and 1 hour**. No daily
  window header exists — say so instead of multiplying the hourly cap.
- `x-nous-credits-*` headers identify the tier directly:
  `paid-access: false` + `subscription-usd: 0.00` = Free.
- Paid models on a zero-balance account fail with
  `404 insufficient_credits_for_paid_model` — not a rate limit.
- Free models return `200` with zero credits; request quota is what
  binds.
- No public usage endpoint: `/api/usage`, `/api/v1/usage`, `/api/limits`,
  `/api/quota`, `/api/credits`, `/api/keys`, `/api/me`, `/api/account`
  all return `404` even with a valid bearer token.

## OpenRouter (`openrouter.ai/api/v1`)

Auth: `OPENROUTER_API_KEY` from `~/.hermes/.env`. Read it with
`grep -oP 'OPENROUTER_API_KEY=\K.*' ~/.hermes/.env | tr -d '\r"'`.

### `GET /api/v1/key` (per-key state)

```
label, limit, limit_reset, limit_remaining, include_byok_in_limit,
usage, usage_daily, usage_weekly, usage_monthly, byok_usage*,
is_free_tier, free_model_daily_requests: {used, limit, remaining}
```

`rate_limit` in the response is deprecated — ignore it.

### `GET /api/v1/credits` (account balance)

`total_credits` / `total_usage`; remaining = difference. **This is the
ACCOUNT balance and is not what gates a request** — a per-key `limit`
of `$0` blocks paid models while the balance is positive.

### Free-model limits

| All-time credits purchased | Requests/min | Requests/day |
|---|---|---|
| < 10 | 20 | 50 |
| ≥ 10 | 20 | 1000 |

The daily tier is selected by all-time purchase, independently of
`is_free_tier`. Counters live in `free_model_daily_requests`; the RPM
cap is not reported there.

### Error shapes

- `403` + `error.metadata.limit_source: "openrouter_key_limit"` — the
  key's own spending cap; fix at `openrouter.ai/settings/keys`.
- `402` — account credit limit (balance or key cap).
- `429` — rate limit; read `X-RateLimit-*` on the error response.
- `404` on a `:free` slug — the free variant was retired; the error
  names the paid slug. Not a quota problem.

## Generic rules

- Probe with `"max_tokens": 1` so a limits check costs nothing.
- Token caps count **input + output**; a big-context agent turn hits TPM
  first.
- Distinguish the three failure classes before diagnosing: `429`
  (rate), `402` (credit), `403` (key cap / permission). They have
  different remedies and only one is "you ran out".
- Never state a limit as a single number without naming its window.

