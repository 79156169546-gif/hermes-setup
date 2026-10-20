---
description: Use when researching and writing a company analysis report.
name: business-analysis
version: 1.0.0
author: hermes-agent
license: proprietary
metadata:
  hermes:
    tags:
      - business-analysis
      - web-research
      - report-writing
      - company-analysis
    related_skills:
      - file-editing-workflow
---

## When to use

Whenever you need to analyze a specific business, medical center, company, or competitor from open web sources and deliver a structured report to this user. Triggers: "анализ бизнеса", "разбери компанию", "проанализируй рынок", "сделай разбор от а до я", or any request to research and write up a business assessment.

## Always-on rules

1. **Language.** Write the report in Russian. No filler phrases ("Great question," "I'd be happy to"), no restating the request, no process narration. Plain claims over adjectives.
2. **Parallel research.** Batch independent web_search calls in one turn — one per search angle (official site, reviews/ratings, prices, legal registry, competitors, market data).
3. **Marker-aware retrieval.** Every web_search result returns <<<CCR:hash|type|size>>> markers. Retrieve each marker's content with aphrodite_retrieve before moving to the next research step; do not ignore markers as opaque tokens.
4. **Full read before write.** Always call read_file without offset/limit before write_file on an existing file. A partial read sets a freshness flag that blocks overwrites.
5. **No blocked-write retries.** If write_file returns stale_write_blocked, do not retry unchanged. Do a full read_file first, or switch to patch for targeted edits.
6. **File destination.** Write the report directly into the user's target folder (e.g. C:\Users\79156\OneDrive\Desktop\new\). Do not describe it in chat instead of writing it.
7. **Report structure.** Company card → services & prices → competitor comparison → reputation & reviews → market & segment → legal analysis → SWOT → quick wins → service additions → roadmap → risks → verdict → sources.
8. **Source attribution.** Every factual claim must cite its URL/source in a numbered sources section at the end.
9. **Uncertainty flag.** Mark any figure not confirmed from open sources as an estimate; do not invent revenue, headcount, or visit data.

## Pitfalls

- **stale_write_blocked loop.** write_file refuses to overwrite when the file was last read with offset/limit pagination. The fix: full read_file, then retry write_file or use patch. Never repeat the same blocked write_file call.
- **CCR marker not retrieved.** Aphrodite markers are content, not pointers to ignore. Retrieve each one before the step that needs it; skipping leaves gaps in the report.
- **Partial web extract.** web_extract can return truncated content when multiple URLs are batched. If the result is suspiciously short, re-extract URLs one at a time.
- **Missing legal entity.** Open sources may not reveal the local legal entity for a branch office. State "not found in open sources" rather than guessing; do not fabricate INN/OGRN.

## Procedure

1. **Search angles (parallel).** Launch 3–5 web_search calls: official site, reviews/ratings, prices, legal registry (ИНН/ОГРН/лицензия), competitors/market data.
2. **Retrieve markers.** For each search result marker, call aphrodite_retrieve to get the full content. Batch multiple retrieves in one turn.
3. **Extract official pages.** web_extract the company's official site: homepage, contacts, services, prices. If batched extraction returns truncated content, re-extract URLs individually.
4. **Compile report.** Build the structured report per the Always-on rule #7 order, using retrieved source content.
5. **Write file.** Write to the target folder. If blocked, full read + patch bypass per Always-on rules #4–5.
6. **Verify.** Confirm the file was written with read_file (full, no offset/limit).

