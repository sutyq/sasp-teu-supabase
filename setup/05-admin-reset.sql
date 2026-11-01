-- =====================================================
-- SASP TEU — Admin reset (hromadné mazání pro restart serveru)
-- =====================================================
-- Spusť v Supabase SQL Editoru. Bezpečné spustit opakovaně.
--
-- Proč funkce a ne přímý DELETE z prohlížeče:
--  * kontroluje se přímo v databázi, že volající je admin
--    (běžný officer to nespustí, ani kdyby obešel UI)
--  * obejde RLS u tabulek, kde nemusí být povolený DELETE
--    (typicky activity_log), takže se nestane, že appka
--    napíše "smazáno" a ve skutečnosti se nic nesmazalo
--  * vrací skutečný počet smazaných řádků
-- =====================================================

create or replace function admin_reset(target text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from officers
    where lower(email) = lower(auth.jwt() ->> 'email')
      and is_admin = true
  ) then
    raise exception 'Pouze admin může provést reset';
  end if;

  -- "where true" kvůli ochraně proti DELETE bez WHERE (pg_safeupdate)
  if target = 'vehicles' then
    delete from vehicles where true;
  elsif target = 'response_vehicles' then
    delete from response_vehicles where true;
  elsif target = 'activity_log' then
    delete from activity_log where true;
  else
    raise exception 'Neznámý cíl: %', target;
  end if;

  get diagnostics n = row_count;
  return n;
end;
$$;

-- Jen přihlášení uživatelé (a uvnitř funkce se ještě kontroluje admin)
revoke all on function admin_reset(text) from public, anon;
grant execute on function admin_reset(text) to authenticated;
