# Provider CLI setup, auth flows, and service creation

Per-provider detail for `paas-deployment`. Verify against the CLI's own
`--help` before trusting a flag; vendors move flags between releases.

---

## Netlify (static frontend)

### Install

```bash
npm i -g netlify-cli
netlify --version
```

### Auth

`netlify login` runs a browser ticket flow: it prints
`https://app.netlify.com/authorize?response_type=ticket&ticket=<id>` and
polls until the ticket is approved. The account is created on first approval.

The browser must reach that URL — the flow fails if the user is not signed
in to the provider in that browser profile. Hand the URL to the user; do not
drive the consent form for them.

### Verify

```bash
netlify status                     # prints the current user's name/email
netlify api getCurrentUser         # structured payload — prefer this
```

Credential lands in `~/.netlify/config.json`.

### Deploy

```bash
cd frontend
npm run build                      # VITE_API_BASE must already be set
netlify deploy --prod --dir=dist
```

The deploy prints the public URL (`https://<site>.netlify.app`). A site
created implicitly by the first deploy gets a generated name; pass `--site
<name>` to choose one, or `netlify sites create --name <name>` first.

### Static-host config

`netlify.toml` pins build/publish and adds the SPA rewrite. See
`templates/netlify.toml`.

**Placement follows the deploy directory.** Netlify reads the config from the
directory the deploy runs in, not from the repo root. When you run
`netlify deploy --dir=dist` from `frontend/`, the file must be at
`frontend/netlify.toml`; a root-level `netlify.toml` is ignored. A root file
with `base = "frontend"` is for Git-connected builds only. Drop the `base`
key when the file sits next to the `package.json` it builds.

### Pre-create the site

```bash
netlify sites:create --name avtodom-storefront --disable-linking
```

Lets you pick the final subdomain before the first deploy (the URL is
`https://<name>.netlify.app`) and confirms the CLI works before a build is
involved. `--disable-linking` keeps the site out of the folder's link state.
The site id is in the JSON output.

**Pass the site by ID, not by name.** `netlify deploy --site=<name>` fails
with "Failed retrieving site data for site <name>: Not Found" — the CLI's
name lookup does not work on every account. Link once and let the deploy
pick it up:

```bash
netlify link --id <site_id>      # writes frontend/.netlify/state.json
netlify deploy --prod --dir=dist
```

### `netlify deploy` rebuilds the project

`netlify deploy` executes `[build].command` from `netlify.toml` itself, so
it **overwrites** a bundle you built by hand — and it rebuilds without
whatever env vars your manual build had. A bundle that correctly embeds
`VITE_API_BASE` is silently replaced by one that does not.

Pass the variable to the deploy process itself, not only to `npm run build`:

```bash
VITE_API_BASE=https://api.example.com netlify deploy --prod --dir=dist
```

Verify afterwards that the served `index.html` points at the bundle you
expect (the hashed filename changes when the bundle content changes) and that
the new bundle really contains the API URL.

### Edge Access (SSO) can lock a fresh site

A newly created site can answer `401` with a "Login Redirect" body pointing
at `app.netlify.com/edge-access`. The setting lives on the ACCOUNT
(`site_sso_login`), and the account-level PATCH is refused with "Account is
not eligible to update global access controls" — but the per-site override
works:

```bash
curl -X PATCH https://api.netlify.com/api/v1/sites/<site_id> \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"sso_login": false}'
```

The token lives in `~/AppData/Roaming/netlify/Config/config.json` under
`users.<id>.auth.token`. Verify with a plain GET of the site root: it must
return the app HTML, not a redirect.

---

## Render (Python API)

### Install

The npm packages named `renderinc/cli` and `render-cli` are not Render's
CLI. Render ships a Go binary on GitHub releases:

```bash
VER=$(curl -s https://api.github.com/repos/render-oss/cli/releases/latest \
      | grep -oE '"tag_name": "v[^"]+"' | head -1 | sed 's/.*"v\([^"]*\)"/\1/')
curl -sL -o cli.zip \
  "https://github.com/render-oss/cli/releases/download/v${VER}/cli_${VER}_windows_amd64.zip"
unzip -o cli.zip && chmod +x render.exe && mv render.exe ~/bin/
```

Render's own docs also publish `go install github.com/render-oss/cli@latest`.

### Auth

`render login` prints a device code and a dashboard URL
(`https://dashboard.render.com/device-authorization/<code>`), then polls.
Hand both to the user.

Two failure modes worth knowing:

- **`Error: slow_down`** — the poll was rate-limited. The CLI exits, but the
  browser half of the flow may have already completed the account creation
  and sign-in. Re-run `render login`; with the account now existing, the
  Google sign-in in the user's browser completes without a password prompt.
- **A first sign-in that demands the Google password** is usually an
  account-creation step, not a credential check. The second attempt, after
  the account exists, goes through the remembered session.

So: run the login, drive the browser to the provider's own sign-in button
only (never the consent form), and re-run the CLI if the poll errors — the
retry is often what completes the handshake.

Credential lands in `~/.render/cli.yaml` under `api.key` (not `token:`), and
the active workspace is stored in the same file. To call the API directly:

```bash
AUTH=$(sed -n 's/^ *key: *//p' ~/.render/cli.yaml | head -1)
curl -s -H "Authorization: Bearer $AUTH" https://api.render.com/v1/owners
```

### Workspace

Every service command needs an active workspace. List them from the API
(`GET /v1/owners` returns `[{cursor, owner:{id,name,type}}]`) and set:

```bash
render workspace set "<name>" --confirm
render workspace current
```

### Create a service

Render builds from a **connected git repository** — there is no
"deploy this local folder" mode, so the repo must exist on GitHub/GitLab/
Bitbucket and the repo URL is a required flag.

**The repo must be PUBLIC unless the Render account has the GitHub app
installed.** Without that OAuth connection Render refuses the URL with
"passed in repository URL is invalid or unfetchable" — this is not a bad URL,
it means Render cannot see the repo. A public repo is cloned over plain
HTTPS with no account link at all, so it works immediately. Verify with a
throwaway service on a known public repo before assuming the URL is wrong.

Create the service with the CLI (it assembles the API payload correctly —
hand-built `POST /v1/services` bodies keep failing validation on
`ownerID` / `serviceDetails` / `envSpecificDetails` / `buildCommand`):

```bash
render services create \
  --type web_service \
  --name avtodom-api \
  --repo https://github.com/<user>/<repo> \
  --branch main \
  --root-directory backend \
  --runtime python \
  --plan free \
  --build-command "pip install -r requirements.txt" \
  --start-command "uvicorn main:app --host 0.0.0.0 --port $PORT" \
  --env-var KEY=VALUE \
  --env-var KEY2=VALUE2 \
  --health-check-path /api/health
```

`--type` is required and its valid values are `web_service`,
`private_service`, `background_worker`, `static_site`, `cron_job`. Delete a
probe service with `render services delete <srv-id> --confirm`.

Every service command needs a workspace: `render workspace set "<name>"`,
then `render services list`.

`--env-var` is repeatable. Free-tier web services sleep after inactivity and
cold-start slowly — a first health check right after deploy can take a
minute.

**Env changes need a new deploy, not a restart.** `render restart` reuses
the running instance and keeps the old environment; the new `CORS_ORIGINS`
only takes effect after `render deploys create <id> --clear-cache`. Verify
with a real `Origin` header — `Access-Control-Allow-Origin: *` on a request
that carries the frontend origin means the change has not been applied yet.

`render services update <id> --root-directory backend` sets `rootDir`
(it is read back at the top level of the service object). There is no CLI
flag for env vars, but `PUT /services/<id>/env-vars` with the full list
updates them.

### Python API on Render

- `requirements.txt` must be pinned and complete; the build command is
  `pip install -r requirements.txt`.
- With `--root-directory backend`, the start command runs from that folder
  and `main.py` is imported as a **top-level** module. Relative imports
  (`from . import db`) fail — use dual-mode try/except imports so the same
  tree also runs as `uvicorn backend.main:app` locally.
- Pass `DATABASE_URL` as an env var; never bake it into the repo.
- A background poller (Telegram long-polling, webhooks) is fine on a free
  web service, but it holds the instance awake — budget for the always-on
  cost or move it to a background worker.

---

## Vercel (alternative static host)

```bash
npm i -g vercel
vercel login                       # device code: https://vercel.com/oauth/device?user_code=XXXX
cd frontend && vercel --prod
```

Device flow: `vercel login` prints a `user_code` and polls a token endpoint.
The user approves in their browser. If the poll ends with a transport error
the code may be consumed — re-run `vercel login` for a fresh one.

Vercel needs `VITE_API_BASE` in the project's environment settings, and it
builds the project itself, so the variable IS inlined at build time there.
When deploying a prebuilt `dist/` instead, the value must be set during the
local build.

---

## GitHub CLI

```bash
VER=$(curl -s https://api.github.com/repos/cli/cli/releases/latest \
      | grep -oE '"tag_name": "v[^"]+"' | head -1 | sed 's/.*"v\([^"]*\)"/\1/')
curl -sL -o gh.zip \
  "https://github.com/cli/cli/releases/download/v${VER}/gh_${VER}_windows_amd64.zip"
unzip -o gh.zip && cp gh/bin/gh.exe ~/bin/
```

The npm package named `gh` is unrelated to GitHub CLI.

### Auth

```bash
gh auth login --web --hostname github.com --git-protocol https --skip-ssh-key
```

Prints a one-time code and opens `https://github.com/login/device`. In a
browser already signed in to GitHub the page goes straight to "Continue as
<login>" — one click, no password. The user performs that click.

**Do not drive the consent form yourself.** Open the device page in the
user's browser, then wait for their explicit confirmation. Polling the
process in a loop is not the wait — the wait is them acting.

A device code expires (~15 min). If the wait runs long, kill the process,
start a new `gh auth login`, and give the user the fresh code rather than
letting a dead code block the deploy.

To check the page state without acting on it, read the DOM: the account
name appears in "Signed in as <login>".

**On Windows, gh reads a different config path than Linux.** It looks in
`%APPDATA%\GitHub CLI\hosts.yml`, not `~/.config/gh/hosts.yml`. A token
written to the wrong place makes `gh auth status` report "not logged in"
even though the file exists and is correct. Write to both, or check where
the installed binary actually looks:

```bash
gh auth status        # prints the path it used, e.g.
                       # ✓ Logged in to github.com account X (C:\Users\...\AppData\Roaming\GitHub CLI\hosts.yml)
```

After writing a token by hand, run `gh auth setup-git` — it points git at
`gh` as the credential helper, so `git push` authenticates without a token
in the remote URL. Never leave a token embedded in `.git/config`; it is
plaintext on disk and leaks into `git remote -v` output.

### Verify — do not grep the status text

```bash
gh auth status        # prints "You are not logged into any GitHub hosts." on failure
gh api user --jq .login
```

`gh auth status` on failure still contains the substring "logged in", so
`gh auth status | grep -i "logged in"` reports success while unauthenticated.
Require `gh api user` to return a payload.

### Push the repo

```bash
gh repo create avtodom --private --source=. --remote=origin --push
```

A private repo keeps the source out of public view; the PaaS build then
needs repo access granted to the provider account.

**When `git push` hangs.** HTTPS push can block on an interactive password
prompt that never arrives, and `gh auth login --web` expires after ~15
minutes while the user is away. When both paths stall, upload the tree with
the Git Data API instead — it needs only a PAT and no interactivity:

```bash
# 1. blob per file, 2. tree, 3. commit, 4. patch the ref
curl -X POST https://api.github.com/repos/OWNER/REPO/git/blobs \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"content":"<base64>","encoding":"base64"}'
```

A repo with no commits rejects blob creation with "Git Repository is
empty." — create the first commit through `PUT /contents/<file>` first, then
continue with the Data API.

**Uploading through the Data API creates a separate history.** The local
branch and the remote then have unrelated commit graphs, and the next
`git push` is rejected as non-fast-forward even though the file contents
are identical (git normalises CRLF/LF, so `git diff` shows differences
while the bytes match). Reconcile by resetting the local branch onto the
remote:

```bash
git fetch origin main
git diff --stat origin/main HEAD     # shows files; verify they are only
                                     # line-ending differences
git reset --hard origin/main
git push origin main                 # now: Everything up-to-date
```

Compare the actual bytes before resetting — `git diff` alone is misleading
across platforms.

**The browser session is a fallback, not a shortcut.** A signed-in GitHub
browser profile can regenerate a PAT (Settings → Developer settings →
Personal access tokens → Regenerate) and post it to a local helper that
writes `~/.config/gh/hosts.yml`; `gh` then authenticates with
`GH_TOKEN=<token>`. The browser cannot reach `api.github.com` for writes
(422 — CSRF), so file uploads still need the Data API.

### Read the service's own fields, not the create-response

`render services create` echoes the config it accepted, but the API returns
some fields in unexpected places. Check the service afterwards:

- `rootDir` lives at the TOP level of the service object, not in
  `serviceDetails`.
- `buildCommand` / `startCommand` land in `serviceDetails.envSpecificDetails`.
- Env vars come back from `GET /services/<id>/env-vars` as
  `[{cursor, envVar: {key, value}}]` — a flat `envVars` list is a lie.
- `POST /v1/services` rejects hand-built bodies until they carry
  `ownerID`, `serviceDetails`, `envSpecificDetails` and `buildCommand`;
  the CLI assembles the right shape, so prefer
  `render services create` over a hand-rolled API call.
