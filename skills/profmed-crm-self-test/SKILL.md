---
name: profmed-crm-self-test
description: Use when editing ProfMed CRM code. Runs verification, seeding, and fuzzy-match checks before declaring work done.
category: software-development
---

# ProfMed CRM — Self-Test Skill

Use when editing ProfMed CRM code. Runs verification, seeding, and fuzzy-match checks before declaring work done.

## When to use
After any edit to `app.py`, `database.py`, or `data_loader.py` in `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/`.

## Steps

### 1. Import check
```bash
cd "C:/Users/79156/OneDrive/Desktop/new/profmed_crm"
python -c "import app; import database; import data_loader; print('ALL IMPORTS OK')"
```
If ImportError → fix the missing name, re-run. Common cause: function defined in `data_loader.py` but imported from `database`.

### 2. Database function check
Verify these functions exist and work:
- `upsert_competitor`, `upsert_competitor_price`, `get_competitors`, `get_competitor_prices`, `get_price_comparison`, `get_price_comparison_flat`, `get_fuzzy_price_comparison`, `find_fuzzy_match`, `seed_competitors_and_prices`
- `upsert_review`, `update_kpi_snapshot`, `get_latest_kpi`, `get_reviews_by_platform`
- `upsert_service`, `upsert_service_price`

Test pattern: create → read → update (same ID) → delete.

### 3. Parser check
```python
from data_loader import load_services_from_site
data = load_services_from_site()
assert data['errors'] == []
assert len(data['services']) > 100
```
profmedrzn.ru must return 200+ services with no errors.

### 4. Medical filter check
```python
from data_loader import _is_medical_organization
# Must pass:
assert _is_medical_organization('Клиника здоровья') == True
assert _is_medical_organization('Диагностический центр') == True
assert _is_medical_organization('Стоматология на Вокзальной') == True
# Must fail:
assert _is_medical_organization('Гостиница Рязань') == False
assert _is_medical_organization('Кинотеатр Дружба') == False
assert _is_medical_organization('Вокзал Рязань-1') == False
```
Key bug to avoid: non_medical keywords must match whole words (`\b`) so "Вокзальная" in an address doesn't block a clinic. Add "диагностическ" to medical keywords so "Диагностический центр" is recognized.

### 5. Seed competitors check
```python
from database import seed_competitors_and_prices, seed_base_prices_for_all
stats = seed_competitors_and_prices()
assert stats['competitors_added'] > 0 or stats['competitors_skipped'] > 0
assert stats['prices_added'] > 0 or stats['prices_skipped'] > 0
# Second run should add nothing (idempotent)
stats2 = seed_competitors_and_prices()
assert stats2['competitors_added'] == 0
assert stats2['prices_added'] == 0
# Base prices for all competitors:
stats3 = seed_base_prices_for_all()
assert stats3['added'] > 0
```

### 6. Fuzzy matching check
```python
from database import find_fuzzy_match, get_fuzzy_price_comparison
# Similar names should match:
assert find_fuzzy_match('Приём терапевта', [{'service_name': 'Прием терапевта', 'price': 1000}]) is not None
assert find_fuzzy_match('УЗИ органов брюшной полости', [{'service_name': 'УЗИ брюшной полости', 'price': 1000}]) is not None
# Different services should not match:
assert find_fuzzy_match('Приём терапевта', [{'service_name': 'Стоматология лечение кариеса', 'price': 1000}]) is None
rows = get_fuzzy_price_comparison()
assert len(rows) > 0
```
Threshold: 0.35 minimum. Too low (below 0.35) matches unrelated services like "Общий анализ крови" ~ "Андрофлор-скрин" (0.42). Too high (above 0.35) misses valid short-name matches like "ЭКГ с расшифровкой" ~ "ЭКГ" (0.32).

### 7. Streamlit dataframe check
Before passing a DataFrame to `st.dataframe`, convert ALL column values to strings. Mixed int/float/string in one column causes `pyarrow.lib.ArrowTypeError: Expected bytes, got a float object`. Use `str()` for all values, format prices as `f"{v:g} ₽"`.

### 8. Streamlit launch check
```bash
timeout 10 python -m streamlit run app.py --server.headless true
```
Must start without `Uncaught app execution` or `AttributeError`.

## Common errors & fixes
| Error | Cause | Fix |
|-------|-------|-----|
| `ImportError: cannot import name X from database` | Function defined in `data_loader.py` but imported from `database` | Move import to `import data_loader` and call `data_loader.X()` |
| `StreamlitValueBelowMinError` | `form_number(value=0.0, min_value=1.0)` | Change `value` to `>= min_value` (e.g. `1.0`) |
| `StopIteration` | `next()` on empty list without default | Add `next(..., None)` + check `if not list` |
| Infinite render on competitor tab | 2000+ `st.expander` widgets | Replace with `st.dataframe` table (max 500 rows) |
| Clinic filter false-positives | `вокзал` in address blocks clinic | Use `\b` word boundaries for non_medical keywords |
| Fuzzy match threshold too low | `threshold<0.35` matches unrelated services | Use 0.35 minimum; test with known non-matches |
| Fuzzy match threshold too high | `threshold>0.35` misses short-name matches | Test "ЭКГ с расшифровкой" ~ "ЭКГ" (0.32) |
| `pyarrow.lib.ArrowTypeError` | Mixed int/float/string in one DataFrame column | Convert ALL column values to strings before `st.dataframe` |
| `AttributeError: module data_loader has no attribute X` | Function renamed or moved | Check current function name in `data_loader.py`; update import and call site |

## Exit criteria
- All imports OK
- All DB functions create/read/update/delete without error
- Parser returns 200+ services, 0 errors
- Filter passes all 6 test cases
- Seed is idempotent (second run adds nothing)
- Fuzzy matching passes known match/non-match cases at threshold 0.35
- Streamlit launches without uncaught exceptions
- DataFrame values are all strings (no Arrow conversion error)

After fixing any error, re-run from step 1.

## Files
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/app.py`
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/database.py`
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/data_loader.py`