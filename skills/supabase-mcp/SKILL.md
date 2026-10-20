---
name: supabase-mcp
description: "Manage Supabase projects via MCP connector."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [supabase, mcp, edge-functions, migrations, database]
    related_skills: []
trigger: "Use when the task requires Supabase project management through the Supabase MCP connector (listing projects, applying SQL migrations, deploying or invoking Edge Functions)."
---

## When to Use

Use this skill when you need to manage a Supabase project through the MCP connector: listing projects, applying SQL migrations, deploying Edge Functions, or invoking Edge Functions. Do not use for local Supabase CLI, dashboard UI, RLS authoring, or client-side JS SDK.

## Prerequisites

The Supabase MCP connector must be connected (manage_connections action install/status with supabase). OAuth login grants limited scopes; LIST_ALL_PROJECTS requires a Personal Access Token PAT from Supabase Account Tokens.

## Step 1 — List projects

Call connectors__supabase__LIST_ALL_PROJECTS with no arguments. Returns project refs, names, regions, and statuses. Use the ref for subsequent calls.

Pitfall: OAuth tokens from manage_connections lack Projects.Read scope. If you get 403 Forbidden, generate a PAT at https://supabase.com/dashboard/account/tokens and re-authenticate.

## Step 2 — Apply a database migration

Call connectors__supabase__APPLY_A_MIGRATION with:
- ref: project reference ID
- query: full SQL text

Use for DDL/DML, seed data, or tracked migrations. The migration runs against the project's database directly.

Pitfall: ON CONFLICT clauses referencing tables not in the FROM clause fail with 42P01 missing FROM-clause entry. Use comma-style FROM auth.users au, tenants t instead of CROSS JOIN if the parser chokes.
Pitfall: duplicate key errors 23505 mean the row already exists — check before inserting, or use ON CONFLICT DO NOTHING/DO UPDATE.

## Step 3 — Deploy an Edge Function

Call connectors__supabase__DEPLOY_FUNCTION with:
- ref: project reference ID
- slug: function slug (e.g. ai-assistant, invite-staff, create-owner)
- file_content: raw TypeScript/JavaScript source as a string (preferred for small-to-medium functions)
- file_url: public URL to download source from
- file: local file path (may fail with FILE_UPLOAD_FAILED via gateway)

Pitfall: file_content fails on large files (gateway 400). For functions importing relative modules, inline all constants instead of importing — relative imports break in the deployed bundle.
Pitfall: file local path often fails with FILE_UPLOAD_FAILED through the tool gateway. Prefer file_content or file_url.

## Step 4 — Invoke an Edge Function

Call connectors__supabase__INVOKE_EDGE_FUNCTION with:
- project_ref: project reference ID
- function_slug: function slug
- body: JSON object or raw string (required by some functions even if not documented)
- method: POST default
- headers: optional additional headers
- auth_mode: anon default, service_role, or custom_bearer
- response_type: json, text, or auto

Pitfall: create-owner rejects requests with Invalid JSON if body is omitted. Always pass body for create-owner.
Pitfall: create-owner fails with A user with this email address has already been registered if the email exists in auth.users. It does not fall through to profile creation. Pre-existing users must be handled via direct SQL APPLY_A_MIGRATION on the users table.

## Step 5 — Verify

After deployment, invoke each function with a minimal body to confirm status_code 200 or the expected error shape. After migration, query a table to confirm rows exist.

## Class boundaries

This skill covers Supabase project management via MCP only. It does not cover local Supabase CLI supabase login supabase functions deploy, Supabase dashboard UI, RLS policy authoring, or client-side Supabase JS SDK usage.

## References

None yet — add references/ files only for recurring decision tables error-code-to-fix mappings that appear across multiple sessions.