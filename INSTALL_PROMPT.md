# Промпт для развёртывания этой конфигурации Hermes Agent на новом ПК

Скопируйте блок «ПРОМПТ» целиком и вставьте в Hermes на новом компьютере
(или в любой чат с доступом к терминалу). Агент выполнит установку сам.

---

## ПРОМПТ

```
Установи мне конфигурацию Hermes Agent из репозитория
github.com/79156169546-gif/hermes-setup — той же, что настроена на моём
другом компьютере.

Что нужно сделать, по шагам:

1. Убедись, что Hermes установлен. Если нет — установи:
   curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
   (на Windows: irm https://hermes-agent.nousresearch.com/install.ps1 | iex)
   Если Hermes уже есть — не переустанавливай, просто проверь версию
   командой `hermes --version`.

2. Проверь, что в PATH есть `gh` (GitHub CLI) и `node`/`npx` (нужны для
   MCP-серверов playwright и neon) и `uv`/`uvx` (нужен для MCP-сервера
   tgbot-mcp). Если чего-то нет — установи и скажи мне, что доустановил.

3. Скачай репозиторий с настройками во временную папку:
   git clone --depth 1 https://github.com/79156169546-gif/hermes-setup.git
   и перейди в него.

4. Запусти установку:
   - Linux/macOS:  bash scripts/install.sh
   - Windows:      powershell -ExecutionPolicy Bypass -File scripts\install.ps1
   Скрипт поставит плагины из hermes-pack.yaml (пин на точные коммиты),
   подключит tap со скиллами и установит 11 локальных скиллов по именам,
   применит настройки через `hermes config set` и зарегистрирует MCP-серверы.

5. Секреты в репозитории нет — их нужно задать отдельно. Спроси у меня
   значения и запиши их в `hermes config env-path` (обычно
   ~/.hermes/.env):
   - OPENROUTER_API_KEY — ключ OpenRouter (https://openrouter.ai/keys)
   - EFFORTLESS_HERMES_CUSTOM_API_KEY — обычно тот же ключ
   - HINDSIGHT_API_KEY — ключ Hindsight
   - TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID — только если я их дам;
     без них MCP-сервер tgbot-mcp не ставится, остальное работает.
   Значения запиши в .env, не в config.yaml, и не показывай их в чате
   целиком — достаточно подтвердить, что ключ записан.

6. Проверь результат и покажи мне отчёт:
   - `hermes plugins list --user --plain`   — 10 плагинов, все enabled
   - `hermes skills list --source hub`       — 11 скиллов из tap
   - `hermes mcp list`                      — playwright, neon, supabase,
     tgbot-mcp (если был токен)
   - `hermes config check`                  — без ошибок
   - `hermes doctor`
   Если что-то не установилось — разберись почему и почини, а не
   оставляй на потом.

7. В конце напиши краткую сводку: что установилось, что пропущено и
   что нужно от меня для полного рабочего состояния.

Важно: не выдумывай значения секретов. Если ключа нет у меня — спроси один
раз и дождись ответа. Не коммить .env и не выводи секреты в лог.
```

---

## Что делает скрипт (подробно)

`scripts/install.sh` и `scripts/install.ps1` выполняют одинаковую работу.

### 1. Плагины — одним пакетом

`manifest/hermes-pack.yaml` — декларативный пакет с пином на **точные
коммиты**. Формат родной для Hermes, установка одной командой:

```bash
hermes plugins pack install https://raw.githubusercontent.com/79156169546-gif/hermes-setup/main/manifest/hermes-pack.yaml
```

Состав (все из официального каталога community, кроме двух из git):

| Плагин | Источник | Версия | Зачем |
|---|---|---|---|
| `aphrodite` | PlayForm/Aphrodite-Hermes | 2.2.6 | Сжатие и поиск по контексту |
| `effortless-hermes` | ivcained/effortless-hermes | 0.2.0 | Авто-ревью и полировка результата |
| `hermes-canvas` | tonbistudio/hermes-canvas | 0.1.8 | Дашборд-шаблоны |
| `hermes-trove` | misterdas/hermes-trove | 1.1.4 | Lossless-контекст вместо сжатия |
| `hindsight` | vectorize-io/hindsight | 1.2.2 | Долговременная память |
| `hopper` | mykeura/hopper | 1.4.0 | Планирование задач |
| `prompt-optimizer` | Sahil-SS9/hermes-multichannel-prompt-optimizer | 1.0.0 | Оптимизация промптов |
| `quota` | rarf/hermes-quota-plugin | 2.10.0 | Учёт лимитов провайдера |
| `rtk-rewrite` | kerrz2020/hermes-rtk-rewrite | 1.0.1 | Компактный вывод инструментов |
| `skill-retrieval` | moonlight-lupin/agent-skills | 0.6.0 | Подбор скиллов по запросу |
| `tool-slimmer` | aliasocracy/hermes-tool-slimmer | 0.8.0 | **Отключён** — конфликтует с tool-retrieval |

Пакет ставит плагины, но не управляет тем, какие из них **включены**.
Этим занимается `plugins.enabled` в `config.yaml` — поэтому скрипт
выставляет и его тоже.

### 2. Скиллы — по именам, через tap

11 локальных скиллов лежат в этом репозитории в каталоге `skills/`.
Hermes умеет считать GitHub-репозиторий источником скиллов:

```bash
hermes skills tap add 79156169546-gif/hermes-setup
hermes skills install 79156169546-gif/hermes-setup/skills/paas-deployment --yes
```

Список:

`business-analysis`, `streamlit-sqlite-data-loading`, `supabase-mcp`,
`provider-usage-limits`, `paas-deployment`, `presentation-authoring`,
`catalog-storefront-ui`, `file-editing-workflow`, `postgres-backed-api`,
`profmed-crm-competitors`, `profmed-crm-self-test`

Остальные скиллы (52 штуки) — **встроенные** в Hermes, ставятся вместе с ним
и в установке не участвуют. Их перечень: `hermes skills list --source builtin`.

### 3. Настройки — через `hermes config set`

Правка `config.yaml` вручную запрещена: сбой отступа ломает живой gateway.
Поэтому скрипт идёт через `hermes config set <ключ> <значение>` — это
безопасная точечная запись.

Полный перечень ключей с текущими значениями — в
`manifest/config-settings.yaml` (это справочник, а не готовый конфиг).

Ключевые:

| Ключ | Значение | Смысл |
|---|---|---|
| `model.default` | `minimax/minimax-m3.1-flash:free` | Бесплатная модель |
| `model.provider` | `openrouter` | Провайдер |
| `context.engine` | `hermes-trove` | Lossless-контекст |
| `memory.provider` | `hindsight` | Долговременная память |
| `browser.backend` | `browser-use` | Локальный браузер |
| `browser.use_real_profile` | `true` | Реальный профиль Edge с авторизацией |
| `agent.max_turns` | `150` | Лимит итераций инструментов |
| `compression.threshold` | `0.50` | Сжатие на половине окна |
| `terminal.backend` | `local` | Локальный терминал |
| `telemetry.shared_metrics.send` | `false` | Метрики не уходят наружу |

### 4. MCP-серверы

| Сервер | Транспорт | Назначение |
|---|---|---|
| `playwright` | stdio (`npx @playwright/mcp@latest`) | Браузерная автоматизация |
| `neon` | stdio (`mcp-remote`) | Neon-база (проекты, SQL) |
| `supabase` | HTTP + OAuth | Supabase (проекты, SQL, Edge Functions) |
| `tgbot-mcp` | stdio (`uvx tgbot-mcp`) | Telegram: уведомления и inline-кнопки |

`tgbot-mcp` требует токен бота, поэтому ставится только если
`TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID` заданы в окружении.

---

## Ручная установка (без скрипта)

Если скрипт не подходит — команды по порядку:

```bash
# 1. Плагины
hermes plugins pack install https://raw.githubusercontent.com/79156169546-gif/hermes-setup/main/manifest/hermes-pack.yaml
hermes plugins enable aphrodite
hermes plugins enable effortless-hermes
hermes plugins enable hermes-canvas
hermes plugins enable hermes-trove
hermes plugins enable hindsight
hermes plugins enable hopper
hermes plugins enable prompt-optimizer
hermes plugins enable quota
hermes plugins enable rtk-rewrite
hermes plugins enable skill-retrieval
hermes plugins disable tool-slimmer

# 2. Скиллы
hermes skills tap add 79156169546-gif/hermes-setup
hermes skills install 79156169546-gif/hermes-setup/skills/business-analysis --yes
hermes skills install 79156169546-gif/hermes-setup/skills/streamlit-sqlite-data-loading --yes
hermes skills install 79156169546-gif/hermes-setup/skills/supabase-mcp --yes
hermes skills install 79156169546-gif/hermes-setup/skills/provider-usage-limits --yes
hermes skills install 79156169546-gif/hermes-setup/skills/paas-deployment --yes
hermes skills install 79156169546-gif/hermes-setup/skills/presentation-authoring --yes
hermes skills install 79156169546-gif/hermes-setup/skills/catalog-storefront-ui --yes
hermes skills install 79156169546-gif/hermes-setup/skills/file-editing-workflow --yes
hermes skills install 79156169546-gif/hermes-setup/skills/postgres-backed-api --yes
hermes skills install 79156169546-gif/hermes-setup/skills/profmed-crm-competitors --yes
hermes skills install 79156169546-gif/hermes-setup/skills/profmed-crm-self-test --yes

# 3. MCP
hermes mcp add playwright --command npx --args -y @playwright/mcp@latest
hermes mcp add neon --command npx --args -y mcp-remote https://mcp.neon.tech/mcp --connect-timeout 120
hermes mcp add supabase --url https://mcp.supabase.com/mcp --auth oauth
hermes mcp add tgbot-mcp --command uvx --args tgbot-mcp \
  --env "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" \
  --env "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" --connect-timeout 120

# 4. Настройки — смотри manifest/config-settings.yaml,
#    применять через `hermes config set <ключ> <значение>`
```

---

## Проверка

```bash
hermes plugins list --user --plain   # 10 enabled + tool-slimmer disabled
hermes skills list --source hub      # 11 скиллов, установленных из tap
hermes skills list --source builtin  # 52 встроенных
hermes mcp list                      # 4 сервера
hermes config check
hermes doctor
```

Скиллы, установленные из tap-репозитория, числятся как `hub` (источник
skills.sh), а не `local` — `local` показывает только скиллы, созданные
вручную на этой машине.

---

## Что нужно от человека

| Что | Обязательно | Где взять |
|---|---|---|
| `OPENROUTER_API_KEY` | да | https://openrouter.ai/keys |
| `EFFORTLESS_HERMES_CUSTOM_API_KEY` | да (тот же ключ) | — |
| `HINDSIGHT_API_KEY` | да | https://hindsight.vectorize.io |
| `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` | нет | @BotFather |
| GitHub-авторизация | для установки скиллов | `gh auth login` |

Ключи записываются в `~/.hermes/.env` (путь: `hermes config env-path`).
В `config.yaml` секреты подставляются как `${ПЕРЕGRAMЕННАЯ}` — Hermes
разворачивает их при чтении и никогда не пишет обратно раскрытыми.

---

## Ограничения

- `hermes plugins pack install` тянет плагины по точным коммитам. Чтобы
  обновиться на свежие версии — `hermes plugins update <имя>` и обновить
  `manifest/hermes-pack.yaml` в этом репозитории.
- `hermes skills install` требует доступ к GitHub (rate limit 60 запросов в
  час без авторизации). С `gh auth login` лимит снимается.
- Скилл `tool-slimmer` намеренно отключён: он конфликтует с
  `skill-retrieval` — оба оптимизируют подбор инструментов.
- Конфиг проверен на Hermes `vgit.2d4de4e` (2026.9.24), Windows 11.
  На другой версии часть ключей может называться иначе — `hermes config
  check` покажет расхождения.
