-- =====================================================
-- SASP TEU — Smazání officera smaže i jeho přihlašovací účet
-- =====================================================
-- Když admin smaže řádek v tabulce officers, trigger smaže i účet
-- ve Supabase Auth se stejným e-mailem (editors se uklidí přes
-- ON DELETE CASCADE). Activity log zůstává, drží jen e-mail jako text.
--
-- Účet volajícího se nikdy nesmaže (admin se neodřízne sám).
-- Pozor: omylem smazaný officer musí po znovupřidání projít novou registrací.
-- Bezpečné spustit opakovaně.
-- =====================================================

create or replace function delete_auth_user_on_officer_delete()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if lower(old.email) <> lower(coalesce(auth.jwt() ->> 'email', '')) then
    delete from auth.users where lower(email) = lower(old.email);
  end if;
  return old;
end;
$$;

revoke all on function delete_auth_user_on_officer_delete() from public, anon, authenticated;

drop trigger if exists officers_delete_auth_user on public.officers;
create trigger officers_delete_auth_user
  after delete on public.officers
  for each row execute function delete_auth_user_on_officer_delete();
