-- =====================================================
-- SASP TEU — Add officer rank
-- =====================================================
-- Run in Supabase SQL Editor (Database → SQL Editor → New query)
-- Adds a `rank` column to the existing `officers` table.
-- Safe to re-run (idempotent).
-- =====================================================

alter table officers
  add column if not exists rank text not null default 'Member';

-- Enforce only the 4 allowed values
alter table officers
  drop constraint if exists officers_rank_check;

alter table officers
  add constraint officers_rank_check
  check (rank in ('Member', 'Senior', 'CO', 'XO'));

-- No RLS changes needed — rank is covered by the existing
-- "officers" table SELECT/ALL policies already in 01-schema.sql.
