-- =====================================================
-- SASP TEU — Čekající registrace + vlastní volačka
-- =====================================================
-- Spusť v Supabase SQL Editoru. Bezpečné spustit opakovaně.
-- Vyžaduje current_user_is_admin() ze setup/06-roster-privacy.sql.
--
-- Jméno a volačku zadává člověk při registraci (ukládá se do user_metadata
-- účtu). Admin je vidí v seznamu čekajících, upraví a schválí (vloží do
-- officers) nebo odmítne (smaže účet).
-- =====================================================

-- Účty, které nejsou officeři (jen admin).
create or replace function get_pending_registrations()
returns table (email text, display_name text, callsign text, created_at timestamptz, email_confirmed boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not current_user_is_admin() then
    raise exception 'Pouze admin';
  end if;

  return query
    select u.email::text,
           nullif(btrim(u.raw_user_meta_data ->> 'display_name'), ''),
           nullif(btrim(u.raw_user_meta_data ->> 'callsign'), ''),
           u.created_at,
           (u.email_confirmed_at is not null)
    from auth.users u
    where not exists (select 1 from officers o where lower(o.email) = lower(u.email))
    order by u.created_at desc;
end;
$$;

-- Odmítnutí = smazání účtu. Schváleného officera tudy smazat nejde.
create or replace function reject_registration(p_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not current_user_is_admin() then
    raise exception 'Pouze admin';
  end if;

  if exists (select 1 from officers where lower(email) = lower(p_email)) then
    raise exception 'Tento účet je schválený officer';
  end if;

  delete from auth.users where lower(email) = lower(p_email);
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

-- Officer si smí změnit jen vlastní volačku (RLS na officers zůstává jen pro adminy).
create or replace function update_my_callsign(p_callsign text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := nullif(btrim(p_callsign), '');
begin
  if c is not null and char_length(c) > 30 then
    raise exception 'Volačka může mít nejvýše 30 znaků';
  end if;

  update officers
     set callsign = c
   where lower(email) = lower(auth.jwt() ->> 'email');

  if not found then
    raise exception 'Nejsi officer';
  end if;
end;
$$;

revoke all on function get_pending_registrations() from public, anon;
revoke all on function reject_registration(text) from public, anon;
revoke all on function update_my_callsign(text) from public, anon;
grant execute on function get_pending_registrations() to authenticated;
grant execute on function reject_registration(text) to authenticated;
grant execute on function update_my_callsign(text) to authenticated;
