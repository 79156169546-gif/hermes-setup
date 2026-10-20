#!/usr/bin/env bash
# Воспроизведение конфигурации Hermes Agent на новом ПК.
#
# Требования: hermes в PATH, gh (GitHub CLI) авторизован, python3.
# Секреты НЕ хранятся в этом репозитории — см. manifest/env-vars.md.
#
# Использование:
#   bash scripts/install.sh            # установить всё
#   bash scripts/install.sh --dry-run  # только показать, что будет сделано

set -euo pipefail

REPO_ID="79156169546-gif/hermes-setup"
REPO_RAW="https://raw.githubusercontent.com/$REPO_ID/main"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# ── 0. Проверки окружения ───────────────────────────────────────────────────
say "Проверка окружения"
command -v hermes >/dev/null || { echo "Hermes не найден. Установка: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"; exit 1; }
echo "  hermes: $(hermes --version 2>&1 | head -1)"

# ── 1. Плагины одним пакетом (пин на точные коммиты) ────────────────────────
say "Установка плагинов (hermes-pack.yaml)"
run hermes plugins pack install "$REPO_RAW/manifest/hermes-pack.yaml"

say "Включение/отключение плагинов"
run hermes plugins enable aphrodite
run hermes plugins enable effortless-hermes
run hermes plugins enable hermes-canvas
run hermes plugins enable hermes-trove
run hermes plugins enable hindsight
run hermes plugins enable hopper
run hermes plugins enable prompt-optimizer
run hermes plugins enable quota
run hermes plugins enable rtk-rewrite
run hermes plugins enable skill-retrieval
run hermes plugins disable tool-slimmer

# ── 2. Локальные скиллы по именам через tap ────────────────────────────────
say "Подключение источника скиллов (tap)"
run hermes skills tap add "$REPO_ID"

say "Установка локальных скиллов"
for s in business-analysis streamlit-sqlite-data-loading supabase-mcp \
         provider-usage-limits paas-deployment presentation-authoring \
         catalog-storefront-ui file-editing-workflow postgres-backed-api \
         profmed-crm-competitors profmed-crm-self-test; do
  run hermes skills install "$REPO_ID/skills/$s" --yes
done

# ── 3. Настройки config.yaml ───────────────────────────────────────────────
say "Применение настроек (config set)"
run hermes config set model.default "minimax/minimax-m3.1-flash:free"
run hermes config set model.provider "openrouter"
run hermes config set model.base_url "https://openrouter.ai/api/v1"
run hermes config set model.api_mode "chat_completions"
run hermes config set agent.reasoning_effort "medium"
run hermes config set agent.max_turns "150"
run hermes config set agent.verbose "false"

run hermes config set context.engine "hermes-trove"

run hermes config set memory.provider "hindsight"
run hermes config set memory.memory_enabled "true"
run hermes config set memory.user_profile_enabled "true"
run hermes config set memory.memory_char_limit "2200"
run hermes config set memory.user_char_limit "1375"
run hermes config set memory.nudge_interval "10"

run hermes config set compression.enabled "true"
run hermes config set compression.threshold "0.50"
run hermes config set compression.target_ratio "0.20"
run hermes config set compression.protect_last_n "20"
run hermes config set compression.max_attempts "3"

run hermes config set terminal.backend "local"
run hermes config set terminal.cwd "."
run hermes config set terminal.timeout "180"
run hermes config set terminal.lifetime_seconds "300"
run hermes config set terminal.home_mode "auto"

run hermes config set browser.backend "browser-use"
run hermes config set browser.use_real_profile "true"
run hermes config set browser.inactivity_timeout "120"
run hermes config set browser.font_family "Cascadia Code"

run hermes config set skills.creation_nudge_interval "15"
run hermes config set delegation.max_iterations "250"
run hermes config set code_execution.timeout "300"
run hermes config set code_execution.max_tool_calls "50"
run hermes config set cron.catch_up_missed "true"
run hermes config set kanban.review_dispatch "true"
run hermes config set approvals.destructive_slash_confirm "false"

run hermes config set database.journal_mode "wal"
run hermes config set runtime.nofile_soft_limit "4096"
run hermes config set attachments.storage "hermes-home"

run hermes config set updates.check "true"
run hermes config set updates.pre_update_backup "false"
run hermes config set updates.backup_keep "5"
run hermes config set updates.non_interactive_local_changes "stash"

run hermes config set auth.adopt_external_logins "true"
run hermes config set auth.codex_login_flow "device_code"

run hermes config set telemetry.shared_metrics.enabled "true"
run hermes config set telemetry.shared_metrics.send "false"

run hermes config set auxiliary.compression.provider "auto"

run hermes config set stt.enabled "true"
run hermes config set stt.local.model "base"
run hermes config set stt.local.language "en"
run hermes config set stt.openai.model "whisper-1"

run hermes config set moa.enabled "true"
run hermes config set moa.aggregator.provider "openrouter"
run hermes config set moa.aggregator.model "anthropic/claude-opus-4.8"
run hermes config set moa.degraded_reference_policy "loud"
run hermes config set moa.fanout "user_turn"

# Судья effortless-hermes
run hermes config set plugins.entries.effortless-hermes.settings.judge_backend "custom"
run hermes config set plugins.entries.effortless-hermes.settings.fallback_backend "none"
run hermes config set plugins.entries.effortless-hermes.settings.custom_base_url "https://openrouter.ai/api/v1"
run hermes config set plugins.entries.effortless-hermes.settings.custom_model "inception/mercury-decide:free"
run hermes config set plugins.entries.effortless-hermes.settings.judge_timeout_seconds "15.0"

# ── 4. Список плагинов в config.yaml (pack ставит, список включает) ────────
say "Синхронизация plugins.enabled / plugins.disabled"
run hermes config set plugins.enabled '["aphrodite","effortless-hermes","hermes-canvas","hermes-trove","hindsight","hopper","prompt-optimizer","quota","rtk-rewrite","skill-retrieval","web/ddgs"]'
run hermes config set plugins.disabled '["tool-slimmer"]'

# ── 5. MCP-серверы ─────────────────────────────────────────────────────────
say "Регистрация MCP-серверов"
run hermes mcp add playwright --command npx --args -y @playwright/mcp@latest
run hermes mcp add neon --command npx --args -y mcp-remote https://mcp.neon.tech/mcp --connect-timeout 120
run hermes mcp add supabase --url https://mcp.supabase.com/mcp --auth oauth
# tgbot-mcp требует токен — ставится вручную, см. manifest/env-vars.md
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  run hermes mcp add tgbot-mcp --command uvx --args tgbot-mcp \
    --env "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" \
    --env "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" --connect-timeout 120
else
  echo "  TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID не заданы — tgbot-mcp пропущен."
  echo "  См. manifest/env-vars.md"
fi

# ── 6. Проверка ─────────────────────────────────────────────────────────────
say "Проверка"
run hermes plugins list --user --plain
run hermes skills list --source hub
run hermes mcp list
run hermes config check

printf '\n\033[1;32mГотово.\033[0m Осталось задать секреты в .env — см. manifest/env-vars.md\n'
