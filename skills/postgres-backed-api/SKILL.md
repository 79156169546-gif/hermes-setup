---
name: postgres-backed-api
description: "Use when evolving a FastAPI/asyncpg API on hosted Postgres."
version: 1.0.0
author: hermes-agent
license: proprietary
metadata:
  hermes:
    tags: [postgres, neon, asyncpg, fastapi, schema, migrations, api]
    related_skills: [supabase-mcp, systematic-debugging]
---

# Postgres-Backed API

## When to use

Building or evolving an HTTP API whose data lives in Postgres (Neon, Supabase,
RDS) behind an async driver (asyncpg). Applies when adding tables or columns,
adding filters/search, modelling a catalog/order domain, or debugging type
errors raised by the driver.

## Always-on rules

1. **A schema file that targets a live database needs `ALTER TABLE` for every
   column, not just `CREATE TABLE`.** `CREATE TABLE IF NOT EXISTS` is a no-op
   when the table already exists — it skips the whole table definition, so
   columns added later never appear and the app breaks at runtime with
   "column does not exist". Pair each `CREATE TABLE` with a standalone
   `ALTER TABLE <t> ADD COLUMN IF NOT EXISTS <c> <type>` for every column.
2. **Verify the applied schema against `information_schema`, never against the
   migration script's exit code.** A script that ran clean proves only that the
   statements were accepted. Query the column list back.
3. **The driver binds typed Python values — pass typed values.** A `str` bound
   to a date parameter raises `DataError: invalid input for query argument $N`
   because asyncpg tries to coerce the string to a date. Parse dates to
   `datetime.date`, money to `Decimal`, timestamps to `datetime` — before they
   reach the query, not in the SQL.
4. **Snapshot mutable referenced state into the referencing row.** If a
   catalog row's price, availability, or lead time can change after an order
   references it, copy those values into the order line at write time.
   Reading them live through the foreign key lets historical orders drift when
   the catalog is edited.
5. **The server owns prices and totals.** Never accept a price, discount, or
   total from the client — re-read them from the catalog and recompute.
6. **Narrow the input contract, keep the stored contract wide.** When an
   option is retired (delivery removed), reject it on input but keep the
   historical value in the column and in the read model. Rewriting stored rows
   destroys history.
7. **Build dynamic filters with parameters in numbering order.** Append each
   value to the parameter list as you add its placeholder, and keep the
   placeholder index in sync with the list position.
8. **Run the whole chain before reporting.** Schema → API → UI → tests →
   docs is one deliverable. Finish every layer, then report once; do not stop
   between layers to ask whether to continue.
9. **The health endpoint must report the capability that must work in
   production, not a local config flag.** If a transport is optional in one
   environment but has a working fallback in another, a flag-driven status
   (e.g. "ready" because a feature switch is on) reports a lie once the
   optional transport is missing on the host. Derive the status from the
   resources the service actually needs — credentials present, connection
   established — so the check means the same thing on every host.
10. **A wildcard CORS origin disables credentials.** `allow_origins=["*"]`
   combined with `allow_credentials=True` is rejected by browsers, so the
   preflight fails in the browser while curl still succeeds. When the origin
   list contains `*`, set `allow_credentials=False`.

## Procedure — adding a column to a live table

1. Edit the schema file: add the column to the `CREATE TABLE` block **and** add
   a standalone `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` for it.
2. Apply the schema with the project's apply script.
3. Verify by querying `information_schema.columns` for that table and printing
   the column list.
4. Update the Pydantic models — both the input and the output shape.
5. Update **every** query that returns that row shape: the list endpoint, the
   detail endpoint, the admin endpoint, and any aggregate query. There is
   usually more than one, and missing one produces a 500 that only shows up on
   that route.
6. Update the write path — the `INSERT` column list and the values tuple.
7. Test the read, the write, and the path that should now reject the new
   input.

## Procedure — adding a filter or search to a list endpoint

1. Declare the query parameters on the endpoint, each with a sane default.
2. Parse and validate each one explicitly; raise 422 on a malformed value.
3. Build the `WHERE` clause from the parsed values, appending to the parameter
   list in lockstep with the placeholder numbers.
4. Order by a fixed, whitelisted set of sort keys — never interpolate a raw
   user value into the `ORDER BY` clause.
5. Return a count alongside the rows so the UI can show "found N".

## Pitfalls

- **Trusting `CREATE TABLE IF NOT EXISTS` on a live DB.** The statement is
  accepted, the script exits 0, and the new column is silently absent — the
  failure surfaces much later as a 500 on one route. Verify with
  `information_schema`.
- **Binding a `str` to a date parameter.** asyncpg reports it as a
  `DataError` about the string not having `toordinal`, which reads like a
  type bug in the query rather than a missing conversion at the call site.
  Parse to `datetime.date` first.
- **Forgetting the second `SELECT`.** A new column added to one list query
  but not the detail query gives a 500 on the detail route only. Grep for
  every `SELECT` that names the table.
- **Reading mutable product state live in an order.** A later catalog edit
  rewrites what the customer agreed to. Copy the values into the order line.
- **Letting the client send the price.** Always recompute server-side.
- **Overwriting a shared file to change one field.** Repeated `write_file`
  calls on a file that was read with pagination are refused; delete and
  rewrite, or patch — see the `file-editing-workflow` skill.
- **A health check driven by a feature flag.** It reports the local
  configuration, not the deployed capability, and stays green on a host
  where the feature's dependency is absent.
- **Testing a wildcard CORS origin with curl.** The server answers happily
  while the browser rejects the credentials-plus-wildcard combination.

## References

- `references/asyncpg-types-and-filters.md` — driver type mapping, the
  parameter-binding failure mode, and a worked dynamic-filter builder.
- `paas-deployment` — deploying this API to a hosted free tier (Render
  start command, env vars, CORS wiring, health verification).
