---
name: paas-deployment
description: "Use when deploying a web app to Vercel, Render or Netlify."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [deployment, vercel, render, netlify, paas, cli, static-hosting, free-tier, cors, spa]
    related_skills: [github, postgres-backed-api, catalog-storefront-ui]
---

# PaaS Deployment (free tiers, CLI)

## When to use

Shipping an existing web app to a hosted free tier: a React/Vite frontend to a
static host (Netlify, Vercel, Cloudflare Pages) and a Python API to a
container/PaaS host (Render, Railway, Fly). Covers CLI install, account
authorization, repo/service creation, build-time API wiring, SPA routing,
CORS, and post-deploy verification.

## Always-on rules

1. **Account authorization is the user's job — never automate it.** When a
   provider needs a sign-in, stop and hand the user a link. Never type
   credentials, never guess a password, never auto-submit an OAuth consent
   form on their behalf. The provider owns the credential; you own the
   preparation.
2. **Probe session state, then open only the tabs that still need action.**
   Check each provider's real session (visit its dashboard/API and look for a
   redirect to a login page) before opening anything. Keep every pending auth
   page in ONE browser, close the rest, then **wait for the user's explicit
   "I'm authorized"** — do not poll-loop through their login.
3. **Verify session state through the API, never by grepping a status
   string.** `gh auth status` prints "You are not logged into any GitHub
   hosts" on failure — that line contains "logged in", so a grep for
   "logged in" reports success while unauthenticated. Call `gh api user`
   (or the provider's own `whoami`) and require a real payload.
4. **Install provider CLIs from their official release artifacts, not from a
   guessed npm name.** The npm registry holds unrelated packages under
   plausible names: `gh` is not GitHub CLI, `render-cli` is a template
   linter, `renderinc/cli` does not exist. Get the binary from the vendor's
   GitHub releases (cli/cli for GitHub, render-oss/cli for Render) and put it
   on PATH.
5. **Order the deploy backend-first.** A static frontend bakes its API base
   URL into the bundle at build time, so the backend URL must exist before
   the frontend build runs. Build the frontend with the API base already
   known, or ship a bundle pointing at nothing.
6. **Env vars set in the host dashboard do not affect a prebuilt bundle.**
   When you deploy a prebuilt `dist/`, the bundle already contains the
   inlined values from the build step. Rebuild with the variable set
   (`VITE_API_BASE=... npm run build`) rather than adding it to the host's
   environment settings and hoping.
7. **A single-page app needs a catch-all rewrite on a static host.** Client
   routes such as `/admin`, `/cabinet`, `/login` 404 on hard refresh unless
   every unmatched path rewrites to `/index.html`. Ship a `netlify.toml` /
   `vercel.json` with the rewrite plus the build/publish settings.
8. **An API that must start from a subdirectory needs dual-mode imports.**
   A PaaS with root directory set to `backend/` runs `uvicorn main:app`,
   which loads the module as top-level, so `from . import db` raises
   ImportError. Wrap relative imports in try/except so both
   `uvicorn backend.main:app` and `uvicorn main:app` work.
9. **CORS wildcard and credentials are mutually exclusive.** With
   `allow_origins=["*"]` the browser rejects `allow_credentials=True`
   (the spec forbids `*` with credentials), so the preflight fails in the
   browser while curl still succeeds. Set `allow_credentials=False`
   whenever the origin list contains `*`.
10. **Health must report deployed reality, not a local config flag.** A
    transport that is optional in one environment but has a working fallback
    elsewhere must not be what health reports. Derive the status from the
    capability that actually has to work in production.
11. **Keep secrets out of the pushed repo.** Check the staged file list
    (`git status --porcelain`) for `.env*`, credential files, and generated
    config before the first push — once pushed, the history carries it.

## Procedure — deploy a frontend + backend pair

1. **Prepare the repo.** `git init`, add a `.gitignore` covering
   `.env*`, virtualenvs, `node_modules`, and build output, then commit.
   Verify the staged list has no secrets before continuing.
2. **Install the CLIs** from vendor release artifacts; put them on PATH and
   confirm `--version` for each.
3. **Establish which provider needs which account.** Render-family hosts
   build from a **connected git repository** — there is no "deploy this local
   folder" mode — so a git host account is a hard prerequisite, not an
   optional extra. Static hosts deploy a built directory directly and need
   no repo.
4. **Authorize each provider** (rules 1-3): open the auth page, hand it to
   the user, wait for their go-ahead.
5. **Deploy the backend first** and wait until its health endpoint answers
   from the public URL. Record the public URL — the frontend needs it.
6. **Build the frontend with the API base set** (rules 5-6).
7. **Deploy the frontend** with the host's production flag and the build
   output directory.
8. **Wire CORS** to the frontend's exact public origin (rule 9), then
   re-verify the backend health from the public internet.
9. **Verify end to end in a browser:** the storefront loads, a test order is
   placed, the order reaches the notification channel, and the order appears
   in the owner view. A green build is not a deployed app.

## Pitfalls

- **Assuming a static host's env var can fix a broken bundle.** The variable
  is inlined at build time; changing it in the dashboard and redeploying the
  same `dist/` changes nothing. Rebuild.
- **CORS verified with curl instead of a browser.** A permissive server
  answers curl happily while the browser blocks the preflight. Always check
  the origin pair that the browser will actually send.
- **Trusting a grep over a status command.** Negative status messages often
  contain the positive phrase. Require a structured payload.
- **Installing a CLI from an npm name that merely looks right.** You get a
  working binary for a different product, and the failure appears later as a
  confusing missing-subcommand error.
- **Deploying the frontend before the backend URL is known.** The bundle
  ships with an empty or wrong API base and every request 404s at runtime.
- **Skipping the SPA rewrite.** The first visit works from `/`; every deep
  link and every refresh inside the app 404s.
- **A relative-import crash only on the host.** The app runs locally under a
  package path and dies on the host under a top-level path. Reproduce the
  host's exact start command locally before deploying.
- **Reporting a deploy as done before the public URL answers.** Verify from
  outside the machine, not from localhost.

## References

- `references/provider-cli-setup.md` — per-provider CLI install, auth
  device-flow shapes, credential file locations, and the workspace/service
  creation commands.
- `templates/netlify.toml` — static-host config: SPA rewrite, asset
  caching, security headers.
