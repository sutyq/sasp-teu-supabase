-- =====================================================
-- SASP TEU — Roster privacy
-- =====================================================
-- Problem: policy "officers_read_authenticated" lets ANY logged-in account
-- (even an unapproved sign-up) read the whole officers table: emails, ranks,
-- callsigns, is_admin and rows hidden from the roster.
--
-- Fix in two parts. The ORDER matters.
-- =====================================================


-- ---------- PART 1 — already applied to the live project ----------
-- Roster data now comes from a function that returns only visible officers
-- and only name / rank / callsign (no email, no admin flag). Only approved
-- officers can call it.

create or replace function get_roster()
returns table (display_name text, rank text, callsign text)
language sql
stable
security definer
set search_path = public
as $$
  select o.display_name, o.rank, o.callsign
  from officers o
  where o.visible_in_roster = true
    and exists (
      select 1 from officers me
      where lower(me.email) = lower(auth.jwt() ->> 'email')
    );
$$;

revoke all on function get_roster() from public, anon;
grant execute on function get_roster() to authenticated;


-- ---------- PART 2 — run ONLY after the new index.html is live ----------
-- The old RosterModal reads the officers table directly. Once this part runs,
-- non-admins only see their own row there, so the old Roster would show
-- almost nothing. Deploy the new index.html first, then run this.
--
-- The helper is security definer so the policy can ask "is the caller an
-- admin?" without recursing into the same table's RLS.

create or replace function current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from officers
    where lower(email) = lower(auth.jwt() ->> 'email')
      and is_admin = true
  );
$$;

revoke all on function current_user_is_admin() from public, anon;
grant execute on function current_user_is_admin() to authenticated;

drop policy if exists "officers_read_authenticated" on officers;
drop policy if exists "officers_read_self_or_admin" on officers;
create policy "officers_read_self_or_admin"
  on officers for select
  to authenticated
  using (
    lower(email) = lower(auth.jwt() ->> 'email')
    or current_user_is_admin()
  );
