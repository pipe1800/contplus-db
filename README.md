# ContPlus DB - Supabase Migrations

Database migrations for the ContPlus 6 replacement. PostgreSQL schema migrated from the original Microsoft SQL Server database.

## Stack
- Supabase (PostgreSQL)
- Supabase Migrations
- Supabase CLI for local development

## Setup
```bash
supabase link --project-ref <project-ref>
supabase db push
```

## Structure
- `migrations/` — Versioned SQL migration files
- `seed.sql` — Seed data for development

