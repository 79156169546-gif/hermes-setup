# Windows-версия scripts/install.sh.
#
# Запуск из PowerShell:
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -DryRun
#
# Требуется: hermes в PATH, gh авторизован.

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoId    = "79156169546-gif/hermes-setup"
$RepoRaw   = "https://raw.githubusercontent.com/$RepoId/main"

function Invoke-Step {
    param([string]$Message, [scriptblock]$Action)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [dry-run] $($Action.ToString().Trim())" -ForegroundColor DarkGray
    } else {
        & $Action
    }
}

# ── 0. Проверки ────────────────────────────────────────────────────────────
Write-Host "==> Проверка окружения" -ForegroundColor Cyan
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Host "Hermes не найден в PATH. Установка: irm https://hermes-agent.nousresearch.com/install.ps1 | iex" -ForegroundColor Red
    exit 1
}
Write-Host "  hermes: $(& hermes --version 2>&1 | Select-Object -First 1)"

# ── 1. Плагины ─────────────────────────────────────────────────────────────
Invoke-Step "Установка плагинов (hermes-pack.yaml)" { hermes plugins pack install "$RepoRaw/manifest/hermes-pack.yaml" }

Invoke-Step "Включение/отключение плагинов" {
    foreach ($p in @("aphrodite","effortless-hermes","hermes-canvas","hermes-trove","hindsight",
                     "hopper","prompt-optimizer","quota","rtk-rewrite","skill-retrieval")) {
        hermes plugins enable $p
    }
    hermes plugins disable tool-slimmer
}

# ── 2. Локальные скиллы по именам через tap ───────────────────────────────
Invoke-Step "Подключение источника скиллов (tap)" { hermes skills tap add $RepoId }

Invoke-Step "Установка локальных скиллов" {
    foreach ($s in @("business-analysis","streamlit-sqlite-data-loading","supabase-mcp",
                     "provider-usage-limits","paas-deployment","presentation-authoring",
                     "catalog-storefront-ui","file-editing-workflow","postgres-backed-api",
                     "profmed-crm-competitors","profmed-crm-self-test")) {
        hermes skills install "$RepoId/skills/$s" --yes
    }
}

# ── 3. Настройки ───────────────────────────────────────────────────────────
Invoke-Step "Применение настроек (config set)" {
    $settings = @(
        @("model.default", "minimax/minimax-m3.1-flash:free"),
        @("model.provider", "openrouter"),
        @("model.base_url", "https://openrouter.ai/api/v1"),
        @("model.api_mode", "chat_completions"),
        @("agent.reasoning_effort", "medium"),
        @("agent.max_turns", "150"),
        @("agent.verbose", "false"),
        @("context.engine", "hermes-trove"),
        @("memory.provider", "hindsight"),
        @("memory.memory_enabled", "true"),
        @("memory.user_profile_enabled", "true"),
        @("memory.memory_char_limit", "2200"),
        @("memory.user_char_limit", "1375"),
        @("memory.nudge_interval", "10"),
        @("compression.enabled", "true"),
        @("compression.threshold", "0.50"),
        @("compression.target_ratio", "0.20"),
        @("compression.protect_last_n", "20"),
        @("compression.max_attempts", "3"),
        @("terminal.backend", "local"),
        @("terminal.cwd", "."),
        @("terminal.timeout", "180"),
        @("terminal.lifetime_seconds", "300"),
        @("terminal.home_mode", "auto"),
        @("browser.backend", "browser-use"),
        @("browser.use_real_profile", "true"),
        @("browser.inactivity_timeout", "120"),
        @("browser.font_family", "Cascadia Code"),
        @("skills.creation_nudge_interval", "15"),
        @("delegation.max_iterations", "250"),
        @("code_execution.timeout", "300"),
        @("code_execution.max_tool_calls", "50"),
        @("cron.catch_up_missed", "true"),
        @("kanban.review_dispatch", "true"),
        @("approvals.destructive_slash_confirm", "false"),
        @("database.journal_mode", "wal"),
        @("runtime.nofile_soft_limit", "4096"),
        @("attachments.storage", "hermes-home"),
        @("updates.check", "true"),
        @("updates.pre_update_backup", "false"),
        @("updates.backup_keep", "5"),
        @("updates.non_interactive_local_changes", "stash"),
        @("auth.adopt_external_logins", "true"),
        @("auth.codex_login_flow", "device_code"),
        @("telemetry.shared_metrics.enabled", "true"),
        @("telemetry.shared_metrics.send", "false"),
        @("auxiliary.compression.provider", "auto"),
        @("stt.enabled", "true"),
        @("stt.local.model", "base"),
        @("stt.local.language", "en"),
        @("stt.openai.model", "whisper-1"),
        @("moa.enabled", "true"),
        @("moa.aggregator.provider", "openrouter"),
        @("moa.aggregator.model", "anthropic/claude-opus-4.8"),
        @("moa.degraded_reference_policy", "loud"),
        @("moa.fanout", "user_turn"),
        @("plugins.entries.effortless-hermes.settings.judge_backend", "custom"),
        @("plugins.entries.effortless-hermes.settings.fallback_backend", "none"),
        @("plugins.entries.effortless-hermes.settings.custom_base_url", "https://openrouter.ai/api/v1"),
        @("plugins.entries.effortless-hermes.settings.custom_model", "inception/mercury-decide:free"),
        @("plugins.entries.effortless-hermes.settings.judge_timeout_seconds", "15.0"),
        @("plugins.enabled", '["aphrodite","effortless-hermes","hermes-canvas","hermes-trove","hindsight","hopper","prompt-optimizer","quota","rtk-rewrite","skill-retrieval","web/ddgs"]'),
        @("plugins.disabled", '["tool-slimmer"]')
    )
    foreach ($kv in $settings) {
        hermes config set $kv[0] $kv[1]
    }
}

# ── 4. MCP-серверы ─────────────────────────────────────────────────────────
Invoke-Step "Регистрация MCP-серверов" {
    hermes mcp add playwright --command npx --args -y "@playwright/mcp@latest"
    hermes mcp add neon --command npx --args -y mcp-remote "https://mcp.neon.tech/mcp" --connect-timeout 120
    hermes mcp add supabase --url "https://mcp.supabase.com/mcp" --auth oauth

    if ($env:TELEGRAM_BOT_TOKEN -and $env:TELEGRAM_CHAT_ID) {
        hermes mcp add tgbot-mcp --command uvx --args tgbot-mcp `
            --env "TELEGRAM_BOT_TOKEN=$env:TELEGRAM_BOT_TOKEN" `
            --env "TELEGRAM_CHAT_ID=$env:TELEGRAM_CHAT_ID" --connect-timeout 120
    } else {
        Write-Host "  TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID не заданы - tgbot-mcp пропущен (см. manifest/env-vars.md)" -ForegroundColor Yellow
    }
}

# ── 5. Проверка ────────────────────────────────────────────────────────────
Invoke-Step "Проверка" {
    hermes plugins list --user --plain
    hermes skills list --source local
    hermes mcp list
    hermes config check
}

Write-Host ""
Write-Host "Готово. Осталось задать секреты в .env - см. manifest/env-vars.md" -ForegroundColor Green
