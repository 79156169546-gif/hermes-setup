---
name: profmed-crm-competitors
description: Use when managing competitor clinics and price comparison.
category: software-development
---

# ProfMed CRM — Competitor Monitoring & Price Comparison

Use when managing competitor clinics and price comparison in ProfMed CRM. Seeds competitors, fuzzy-matches services, compares prices, exports CSV.

## When to use
Working on `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/` — specifically the `competitors` and `competitor_prices` tables and the `🏥 Конкуренты` tab in `app.py`.

## Steps

### 1. Seed competitors (one-time setup)
```python
from database import seed_competitors_and_prices
stats = seed_competitors_and_prices()
```
Adds 6 pre-defined Ryazan clinics with 31 prices: «Здоровье», «МРТ-Рязань», «Альтернатива», «АвтоМед», «Инвитро», «Улыбка». Idempotent — second run adds nothing.

### 2. Add a competitor manually
```python
from database import upsert_competitor, upsert_competitor_price
cid = upsert_competitor(
    name="Название клиники",
    branch_address="г. Рязань, ул. ...",
    phone="+7 (4912) XXX-XX-XX",
    website="https://site.ru",
    source="manual",
    rating=4.0,
    reviews_count=10,
    notes="Примечания",
)
upsert_competitor_price("Название клиники", "Название услуги", 1200.0)
```

### 3. Parse prices from a competitor website
```python
from data_loader import parse_competitor_prices
parsed = parse_competitor_prices("https://competitor-site.ru", "Имя конкурента")
# Returns {"competitor": str, "url": str, "prices": [{"service_name": str, "price": float}], "errors": []}
# Save selected prices:
from database import upsert_competitor_price
for p in parsed["prices"]:
    upsert_competitor_price("Имя конкурента", p["service_name"], p["price"])
```
Parser looks for pattern `Услуга — цена ₽` in HTML. Filters by medical keywords.

### 4. Compare prices (fuzzy matching)
```python
from database import get_fuzzy_price_comparison, find_fuzzy_match
rows = get_fuzzy_price_comparison()
# Each row: услуга, наша_цена, конкурент, цена_конкурента, разница_₽, разница_%
# Fuzzy matching: similarity threshold 0.55, normalizes case/punctuation/stop-words
match = find_fuzzy_match("Приём терапевта", competitor_services)
```
Never require exact name match — competitor service names differ ("Прием терапевта" vs "Терапевт первичный приём").

### 5. Export to CSV
```python
import csv, os
rows = get_fuzzy_price_comparison()
out_path = os.path.join(os.path.dirname(__file__), "exports", "price_comparison.csv")
with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=["услуга", "наша_цена", "конкурент", "цена_конкурента", "разница_₽", "разница_%"])
    w.writeheader()
    w.writerows(rows)
```

## UI tabs (app.py «🏥 Конкуренты»)
| Tab | Purpose |
|-----|---------|
| 📊 Сравнение цен | Fuzzy-matched price table with color highlighting (🟢 cheaper / 🔴 more expensive), CSV export |
| 🏢 Список конкурентов | Seed button, manual add form, competitor list table |
| 💰 Парсинг цен | Competitor dropdown, URL input, price extraction, save selected prices |

## Common pitfalls
| Pitfall | Mechanism | Fix |
|---------|-----------|-----|
| ImportError: cannot import name from database | Function lives in `data_loader.py`, not `database.py` | Import from `data_loader`, call `data_loader.func()` |
| Fuzzy match threshold too low | 0.3 matches unrelated services (therapist vs dentistry) | Use 0.55 minimum; test with known non-matches |
| Empty competitor dropdown | No competitors seeded yet | Run seed_competitors_and_prices() first |
| Parser returns 0 prices | Site HTML doesn't match `Услуга — цена ₽` pattern | Try manual entry via upsert_competitor_price |
| Infinite render on comparison tab | 2000+ st.expander widgets | Use st.dataframe with max 500 rows |

## Exit criteria
- Seed runs idempotently (second run adds 0)
- Fuzzy match passes known match/non-match cases
- Price comparison returns rows with разница_₽ populated
- CSV export writes valid UTF-8 with BOM

## Files
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/database.py` — seed_competitors_and_prices, get_fuzzy_price_comparison, find_fuzzy_match, upsert_competitor, upsert_competitor_price
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/data_loader.py` — parse_competitor_prices
- `C:/Users/79156/OneDrive/Desktop/new/profmed_crm/app.py` — 🏥 Конкуренты tab UI