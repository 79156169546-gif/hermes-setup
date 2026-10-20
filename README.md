# hermes-setup

Воспроизводимая конфигурация Hermes Agent: плагины, скиллы, MCP-серверы и
настройки — ставится на любой ПК одним промптом.

Задумано так, чтобы на новой машине не копировать файлы вручную, а назвать
имена: плагины — через декларативный пакет с пином на коммиты, скиллы — через
tap-репозиторий, настройки — через `hermes config set`.

## Быстрый старт

Скопируйте промпт из [INSTALL_PROMPT.md](INSTALL_PROMPT.md) и вставьте в Hermes
на новом ПК. Агент выполнит установку сам.

Или вручную:

```bash
git clone --depth 1 https://github.com/79156169546-gif/hermes-setup.git
cd hermes-setup
bash scripts/install.sh            # Linux/macOS
powershell -ExecutionPolicy Bypass -File scripts\install.ps1   # Windows
```

Секреты задаются отдельно — список в [manifest/env-vars.md](manifest/env-vars.md).

## Состав

| Плагин | Версия | Роль |
|---|---|---|
| `aphrodite` | 2.2.6 | Сжатие и поиск по контексту |
| `effortless-hermes` | 0.2.0 | Авто-ревью и полировка результата |
| `hermes-canvas` | 0.1.8 | Дашб��рд-шаблоны |
| `hermes-trove` | 1.1.4 | Lossless-контекст вместо сжатия |
| `hindsight` | 1.2.2 | Долговременная память между сессиями |
| `hopper` | 1.4.0 | Планирование задач |
| `prompt-optimizer` | 1.0.0 | Оптимизация промптов |
| `quota` | 2.10.0 | Учёт лимитов провайдера |
| `rtk-rewrite` | 1.0.1 | Компактный вывод инструментов |
| `skill-retrieval` | 0.6.0 | Подбор скиллов по запросу |
| `tool-slimmer` | 0.8.0 | Установлен, но **выключен** — конфликтует с `skill-retrieval` |

11 локальных скиллов — в каталоге [`skills/`](skills/). 52 встроенных скилла
приезжают с Hermes.

MCP-серверы: `playwright`, `neon`, `supabase` (OAuth), `tgbot-mcp` (нужен токен бота).

## Структура

```
hermes-setup/
├── INSTALL_PROMPT.md          промпт для установки на новом ПК
├── manifest/
│   ├── hermes-pack.yaml       пакет плагинов (пин на коммиты)
│   ├── config-settings.yaml   справочник настроек «ключ: значение»
│   ├── mcp-servers.yaml       конфигурация MCP-серверов
│   ├── env-vars.md            какие секреты задать и куда
│   ├── skills.md              откуда берётся каждый скилл
│   └── plugins-list.txt       вывод `hermes plugins list --user`
├── skills/                    11 локальных скиллов (установка по именам)
├── scripts/
│   ├── install.sh             установка (Linux/macOS)
│   └── install.ps1            установка (Windows)
└── env.example               шаблон .env
```

## Как это работает

**Плагины** — `manifest/hermes-pack.yaml` в родном формате Hermes: список
репозиториев с точными SHA. `hermes plugins pack install` разворачивает их
пачкой, согласия на capabilities остаются per-plugin.

**Скиллы** — этот репозиторий подключается как tap (`hermes skills tap add`),
после чего каждый скилл ставится по идентификатору
`79156169546-gif/hermes-setup/skills/<имя>`.

**Настройки** — только через `hermes config set`. Ручная правка `config.yaml`
запрещена: сбой отступа ломает живой gateway.

**Секреты** — в `~/.hermes/.env`. В `config.yaml` подставляются как
`${ПЕРЕМЕННАЯ}`; Hermes разворачивает их при чтении и не пишет обратно
раскрытыми. Поэтому в этом репозитории секретов нет.

## Проверка

```bash
hermes plugins list --user --plain
hermes skills list --source local
hermes mcp list
hermes config check
hermes doctor
```

## Обновление

```bash
hermes plugins update hindsight
hermes plugins pack export --enabled-only --name hermes-setup > manifest/hermes-pack.yaml
git commit -am "обновление pack" && git push
```

## Версии

Проверено на Hermes Agent `vgit.2d4de4e` (2026.9.24), Windows 11.
На другой версии названия ключей могут отличаться — `hermes config check`
покажет расхождения.
