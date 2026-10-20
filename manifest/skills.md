# Скиллы Hermes Agent — откуда каждый берётся.
#
# builtin  — поставляется вместе с Hermes (устанавливать не нужно, 52 шт.)
# local    — этот репозиторий; ставится по имени через skills tap
#
# После установки скиллы перечисляются в `hermes skills list --source hub`
# (источник skills.sh), а не в --source local: установленные из tap
# считаются hub-скиллами.

## Локальные скиллы (из этого репозитория)

Подключение источника:

```bash
hermes skills tap add 79156169546-gif/hermes-setup
```

Установка по имени (для каждого):

```bash
hermes skills install 79156169546-gif/hermes-setup/skills/<имя> --yes
```

Список:

- `business-analysis`
- `streamlit-sqlite-data-loading`
- `supabase-mcp`
- `provider-usage-limits`
- `paas-deployment`
- `presentation-authoring`
- `catalog-storefront-ui`
- `file-editing-workflow`
- `postgres-backed-api`
- `profmed-crm-competitors`
- `profmed-crm-self-test`

## Проверка

```bash
hermes skills list --source hub      # 11 установленных из tap
hermes skills list --source local    # скиллы, созданные вручную на этой машине
hermes skills list --source builtin  # 52 встроенных
```

## Скан безопасности

Hermes сканирует каждый устанавливаемый скилл (`tools/skills_guard.py`).
Verdict `dangerous` блокирует установку даже с `--force`, `caution`
пропускается с `--force`.

Все 11 скиллов этого репозитория проверены сканером и имеют verdict `safe`:

```bash
python -c "
import sys; sys.path.insert(0, r'<путь-к-hermes-agent>')
from tools.skills_guard import scan_skill
from pathlib import Path
for d in sorted(Path('skills').iterdir()):
    print(d.name, scan_skill(d, source='self').verdict)
"
```

Если правка скилла вносит строку, похожую на exfiltration или
непинованную установку, сканер пометит скилл как `dangerous` — и на
новом ПК он не поставится. Проверяйте после каждой правки.
