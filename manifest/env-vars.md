# Переменные окружения — что нужно задать вручную

Секреты **не** хранятся в этом репозитории. Они живут в `~/.hermes/.env`
(Windows: `%LOCALAPPDATA%\hermes\.env`). Путь покажет:

```bash
hermes config env-path
```

---

## Обязательные

| Переменная | Что это | Где взять |
|---|---|---|
| `OPENROUTER_API_KEY` | Ключ OpenRouter — основной провайдер и модель | https://openrouter.ai/keys |
| `EFFORTLESS_HERMES_CUSTOM_API_KEY` | Тот же ключ для судьи effortless-hermes (обычно = `OPENROUTER_API_KEY`) | тот же |
| `HINDSIGHT_API_KEY` | Ключ сервиса памяти Hindsight | https://hindsight.vectorize.io |

## MCP: Telegram

| Переменная | Что это |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Токен бота от @BotFather, например `1234567890:AAH...` |
| `TELEGRAM_CHAT_ID` | ID чата, куда приходят уведомления |

Установка MCP-сервера с этими значениями:

```bash
hermes mcp add tgbot-mcp --command uvx --args tgbot-mcp \
  --env "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" \
  --env "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" --connect-timeout 120
```

## MCP: Neon (база данных)

| Переменная | Что это |
|---|---|
| `NEON_API_KEY` | Ключ Neon для `mcp-remote` (необязателен, если OAuth работает) |

```bash
hermes mcp add neon --command npx --args -y mcp-remote https://mcp.neon.tech/mcp --connect-timeout 120
```

## MCP: Supabase

Авторизация OAuth — интерактивная:

```bash
hermes mcp add supabase --url https://mcp.supabase.com/mcp --auth oauth
hermes mcp login supabase
```

## Необязательные

| Переменная | Зачем |
|---|---|
| `GITHUB_TOKEN` | Для `hermes skills publish` и публикации в репозитории |
| `BROWSERBASE_API_KEY` | Облачный браузер вместо локального Edge-профиля |
| `OPENAI_API_KEY` | Внешний STT (вместо локального whisper) |
| `FAL_KEY` | Генерация изображений |
| `ELEVENLABS_API_KEY` | TTS вместо бесплатного Edge-TTS |

---

## Как правильно хранить

В `config.yaml` секреты подставляются через `${ПЕРЕМЕННАЯ}`:

```yaml
mcp_servers:
  tgbot-mcp:
    command: uvx
    args:
      - tgbot-mcp
      - --env
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - --env
      - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
      - --connect-timeout
      - '120'
```

Hermes разворачивает `${...}` при чтении конфига и не пишет обратно
раскрытое значение. Прямое указание токена в `config.yaml` работает, но
делает секрет видимым при любом `git diff` и в бэкапах — не надо так.

## Шаблон .env

Скопируйте `env.example` в `~/.hermes/.env` и заполните значения.
