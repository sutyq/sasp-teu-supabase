-- =====================================================
-- SASP TEU — Callsign + roster visibility toggle
-- =====================================================
-- Run in Supabase SQL Editor. Safe to re-run (idempotent).
-- =====================================================

alter table officers
  add column if not exists callsign text;

alter table officers
  add column if not exists visible_in_roster boolean not null default true;

-- No RLS changes needed — covered by existing officers table policies.
