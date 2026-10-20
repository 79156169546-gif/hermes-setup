---
name: streamlit-sqlite-data-loading
description: "Load external data into Streamlit SQLite CRUD dashboards."
version: 0.4.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [streamlit, sqlite, data-loading, crud, scraping]
    related_skills: []
---

# Streamlit + SQLite data loading

## When to Use

Use when adding data ingestion (ratings, prices, reviews, etc.) to an existing Streamlit + SQLite CRUD dashboard so the UI shows actual external data instead of static seed values. Use for recurring data refresh from external websites or APIs into a local SQLite-backed Streamlit app.

Don't use for: building a new Streamlit app from scratch, connecting to PostgreSQL/Supabase, or scraping sites that require authenticated sessions or CAPTCHA.

## Procedure

1. **Inspect the app structure.** Read `app.py` to find the menu (`st.sidebar.radio`) and page sections, then read `database.py` to confirm the helper signatures (`insert`, `update`, `fetch_all`, `fetch_one`, `init_db`). Note the DB path constant.
2. **Add DB upsert functions.** In `database.py`, add `upsert_<entity>(...)` that checks for an existing row by natural key (name/title) and either `insert` or `update`. Add `upsert_<entity>_price(...)` or similar for relational tables. Always guard against duplicates.
3. **Create a scraper module.** New file `data_loader.py` next to `app.py`. Use `requests` with a browser-like `User-Agent` and `Accept-Language: ru-RU,ru;q=0.9`. Do NOT use `browser_exec` — the Edge profile is locked and JS-heavy aggregator sites (2GIS, Yandex.Maps, Zoon) won't render.
4. **Parse with regex.** Extract entity–price pairs from HTML with `re.findall`. For profmedrzn.ru the working pattern is `option value="\d+">\s*([^<]{6,120}?)\s*—\s*(\d[\d\s]{2,8})\s*₽`. Clean HTML entities (`&quot;`, `&amp;`, `&#39;`, `&laquo;`, `&raquo;`) and collapse whitespace.
5. **Categorize.** Map parsed names to DB categories by keyword (`узи`→Диагностика, `приём/врач`→Врачи, `анализ/кровь`→Лаборатория, `справка/медосмотр`→Медосмотры и справки).
6. **Wire the UI.** In `app.py`, import the new DB functions and `data_loader`. Add a `st.button` + `st.spinner` block on the relevant page. On success, call the upsert functions for each parsed item and each active branch, then `st.rerun()`.
7. **Competitor monitoring (optional).** Add tables `competitors` and `competitor_prices` via `_ensure_competitors_tables(cur)` in `init_extra_tables()`. Add `upsert_competitor()` and `upsert_competitor_price()` guarded by natural key. Add `get_price_comparison()` that joins own services with competitor prices and sorts by price. Wire a 4-tab UI: price comparison (flat `st.dataframe` table with color-coded diffs, capped at 500 rows, plus CSV export), competitor list (manual add), competitor search (7 queries across 2GIS/Yandex), and price parsing from competitor URLs (regex `name — price ₽`, filter by service keywords).
8. **One-click competitor autoload (optional).** In `data_loader.py`, add `auto_load_competitors_and_prices()` that chains: `find_all_competitors_ryazan_medical()` → filter with `_is_medical_organization()` (regex `` boundaries for non-medical keywords) → dedupe against existing DB rows → `upsert_competitor()` → `_extract_website()` via Yandex search HTML → `parse_competitor_prices()` → `upsert_competitor_price()` for each parsed price. Expose a single `st.button` on the search tab with `st.spinner` and four metrics (found, added, sites found, prices parsed) plus a details expander. Wire it to `st.rerun()` on completion.
9. **Test import.** Run `python -c "import app"` from the project folder. Streamlit warnings about missing ScriptRunContext are expected — ignore them. Verify no ImportError or SyntaxError.

## Pitfalls

- **Edge browser is locked.** Never plan to scrape via `browser_exec`; it cannot open the profile. Use `requests` + regex instead.
- **Aggregator sites are JS-heavy.** 2GIS, Yandex.Maps, Zoon return HTML shells without ratings. Handle gracefully: record the error, show a manual-entry fallback form in the UI, and let the user type values in.
- **`import app` emits Streamlit warnings.** Missing ScriptRunContext and session-state warnings are normal when importing outside `streamlit run`. Do not treat them as failures.
- **Duplicate rows.** Always check `SELECT ... WHERE name=?` before `insert`; re-running the loader must not multiply services or prices.
- **Price parsing.** Strip non-digit characters from price strings (`replace(" ", "")`) before `float()`; spaces appear as thousand separators in Russian-formatted HTML.
- **`next()` without default on empty lists.** `next(x for x in lst if cond)` raises `StopIteration` when the list is empty and crashes the Streamlit page. Always guard with `if not lst:` or use `next((x for x in lst if cond), None)`.
- **`st.expander` explosion.** Rendering one expander per row (e.g. 2400+ services) hangs the browser. Replace per-row expanders with a single `st.dataframe` on a flat list, capped at 500 rows, with optional `df.style.apply(...)` for color-coding diffs.
- **`form_number` min_value validation.** Streamlit validates the initial `value` against `min_value`. If `value=0.0` and `min_value=1.0`, it raises `StreamlitValueBelowMinError`. Set `value=min_value` when the default is below the floor.
- **Import location matters.** Helper functions like `auto_load_competitors_and_prices` live in `data_loader.py`, not `database.py`. Import from the correct module to avoid `ImportError`.
- **Medical org filter word boundaries.** Non-medical keywords (e.g. "вокзал") must be checked with `` word-boundary regex, otherwise "Стоматология на Вокзальной" is falsely excluded. Medical keywords can remain substring matches.

## User preferences

- UI text in Russian. All Streamlit labels, captions, and button text must be Russian.
- Write files in the target project folder, not describe them in chat.
- Concise, direct answers — no filler, no restating the request.