-- =====================================================
-- SASP TEU Vehicle Database — Supabase Schema
-- =====================================================
-- Stav odpovídá živé databázi k 8. 11. 2026 (v0.8).
-- Spusť v Supabase SQL Editoru (Database → SQL Editor → New query).
--
-- Vytvoří: tabulky, RLS politiky, trigger funkce, storage bucket, realtime.
-- Je bezpečné spustit opakovaně.
--
-- Další soubory (05–10) přidávají admin funkce a pozdější změny. Jejich obsah
-- už je tady zahrnutý tam, kde ho schéma potřebuje (current_user_is_admin,
-- hodnost Junior, zamčený log_activity), ale spuštění navíc nic nerozbije.
-- Pořadí pro nové nasazení: 01 → 02 (seed) → 05 → 06 (část 1) → 07 → 08.
-- Soubory 03, 04 a 09 jsou historické migrace; 01 už je obsahuje.
-- =====================================================


-- 1) TABULKY
-- ----------

-- Vozidla a jejich response podle tieru.
create table if not exists vehicles (
  id           text primary key,
  vehicle      text not null,
  tier         text not null check (tier in ('S+', 'S', 'A+', 'A')),
  responses    jsonb not null default '[]'::jsonb,
  notes        text default '',
  image        text,                          -- URL ve Storage nebo cesta v /vehicles
  created_at   timestamptz default now(),
  updated_at   timestamptz default now(),
  updated_by   text,                          -- e-mail posledního editora
  non_locator  boolean not null default false
);
create index if not exists vehicles_tier_idx on vehicles (tier);

-- Response auta (Comet, Dominator, ...). Čtou se dynamicky z DB.
create table if not exists response_vehicles (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  image_url   text,
  notes       text default '',
  active      boolean not null default true,
  sort_order  integer default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- Schválení officeři. Kdo tu není, do appky nevidí.
create table if not exists officers (
  email             text primary key,
  display_name      text,
  is_admin          boolean default false,
  created_at        timestamptz default now(),
  id                uuid not null default gen_random_uuid(),
  rank              text not null default 'Member',
  callsign          text,
  visible_in_roster boolean not null default true
);
alter table officers drop constraint if exists officers_rank_check;
alter table officers add constraint officers_rank_check
  check (rank in ('Junior', 'Member', 'Senior', 'CO', 'XO'));

-- Audit log všech změn (plní ho trigger log_activity()).
create table if not exists activity_log (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz default now(),
  actor_email  text,
  action       text not null,
  entity_type  text not null,
  entity_id    text,
  entity_name  text,
  changes      jsonb
);
create index if not exists activity_log_created_at_idx on activity_log (created_at desc);

-- Starší tabulka, kterou appka nepoužívá (zůstala v živé DB).
create table if not exists editors (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  granted_at  timestamptz default now()
);


-- 2) FUNKCE A TRIGGERY
-- --------------------

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists vehicles_updated_at on vehicles;
create trigger vehicles_updated_at
  before update on vehicles
  for each row execute function set_updated_at();

-- Zapisuje vytvoření / úpravu / smazání do activity_log.
-- Volá se jen z triggerů; zvenčí volat nejde (viz revoke níže).
create or replace function log_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_entity_type text;
  v_entity_id text;
  v_entity_name text;
  v_actor_email text;
  v_changes jsonb;
  v_old_json jsonb;
  v_new_json jsonb;
begin
  if (tg_op = 'INSERT') then
    v_action := 'create';
  elsif (tg_op = 'UPDATE') then
    v_action := 'update';
  elsif (tg_op = 'DELETE') then
    v_action := 'delete';
  end if;

  if tg_table_name = 'vehicles' then
    v_entity_type := 'vehicle';
  elsif tg_table_name = 'officers' then
    v_entity_type := 'officer';
  elsif tg_table_name = 'response_vehicles' then
    v_entity_type := 'response_vehicle';
  else
    v_entity_type := tg_table_name;
  end if;

  v_actor_email := auth.jwt() ->> 'email';

  if (tg_op = 'DELETE') then
    v_old_json := to_jsonb(OLD);
    v_new_json := null;
  elsif (tg_op = 'INSERT') then
    v_old_json := null;
    v_new_json := to_jsonb(NEW);
  else
    v_old_json := to_jsonb(OLD);
    v_new_json := to_jsonb(NEW);
  end if;

  -- id a název se čtou z jsonb, aby funkce nezáležela na sloupcích konkrétní tabulky
  if (tg_op = 'DELETE') then
    v_entity_id := COALESCE(v_old_json ->> 'id', '');
    if tg_table_name = 'vehicles' then
      v_entity_name := v_old_json ->> 'vehicle';
    elsif tg_table_name = 'officers' then
      v_entity_name := COALESCE(v_old_json ->> 'display_name', v_old_json ->> 'email');
    elsif tg_table_name = 'response_vehicles' then
      v_entity_name := v_old_json ->> 'name';
    else
      v_entity_name := null;
    end if;
  else
    v_entity_id := COALESCE(v_new_json ->> 'id', '');
    if tg_table_name = 'vehicles' then
      v_entity_name := v_new_json ->> 'vehicle';
    elsif tg_table_name = 'officers' then
      v_entity_name := COALESCE(v_new_json ->> 'display_name', v_new_json ->> 'email');
    elsif tg_table_name = 'response_vehicles' then
      v_entity_name := v_new_json ->> 'name';
    else
      v_entity_name := null;
    end if;
  end if;

  v_changes := jsonb_build_object('before', v_old_json, 'after', v_new_json);

  insert into public.activity_log (
    actor_email, action, entity_type, entity_id, entity_name, changes
  ) values (
    v_actor_email, v_action, v_entity_type, v_entity_id, v_entity_name, v_changes
  );

  if (tg_op = 'DELETE') then
    return OLD;
  else
    return NEW;
  end if;
end;
$$;

revoke execute on function log_activity() from public, anon, authenticated;

drop trigger if exists log_vehicles_activity on vehicles;
create trigger log_vehicles_activity
  after insert or update or delete on vehicles
  for each row execute function log_activity();

drop trigger if exists log_response_vehicles_activity on response_vehicles;
create trigger log_response_vehicles_activity
  after insert or update or delete on response_vehicles
  for each row execute function log_activity();

drop trigger if exists log_officers_activity on officers;
create trigger log_officers_activity
  after insert or update or delete on officers
  for each row execute function log_activity();

-- "Je volající admin?" — security definer, aby se politiky na officers
-- neodkazovaly samy na sebe (jinak nekonečná rekurze v RLS).
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


-- 3) ROW-LEVEL SECURITY
-- ---------------------
-- Číst a upravovat vozidla, fleet a log smí jen přihlášený officer (e-mail v officers).
-- Seznam officerů vidí každý jen u sebe, admin všechny. Měnit ho smí jen admin.
-- (Politiky jsou 1:1 podle živé DB, proto jsou některé "to public" — bez JWT s e-mailem
-- se stejně nikdo do podmínky nedostane.)

alter table vehicles          enable row level security;
alter table response_vehicles enable row level security;
alter table officers          enable row level security;
alter table activity_log      enable row level security;
alter table editors           enable row level security;

-- vehicles
drop policy if exists "only approved officers can view vehicles" on vehicles;
create policy "only approved officers can view vehicles"
  on vehicles for select to authenticated
  using (exists (select 1 from officers where officers.email = (auth.jwt() ->> 'email')));

drop policy if exists vehicles_read_officers on vehicles;
create policy vehicles_read_officers
  on vehicles for select
  using ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists vehicles_insert_officers on vehicles;
create policy vehicles_insert_officers
  on vehicles for insert
  with check ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists vehicles_update_officers on vehicles;
create policy vehicles_update_officers
  on vehicles for update
  using ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists vehicles_delete_officers on vehicles;
create policy vehicles_delete_officers
  on vehicles for delete
  using ((auth.jwt() ->> 'email') in (select email from officers));

-- response_vehicles
drop policy if exists response_vehicles_read_officers on response_vehicles;
create policy response_vehicles_read_officers
  on response_vehicles for select
  using ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists response_vehicles_insert_officers on response_vehicles;
create policy response_vehicles_insert_officers
  on response_vehicles for insert
  with check ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists response_vehicles_update_officers on response_vehicles;
create policy response_vehicles_update_officers
  on response_vehicles for update
  using ((auth.jwt() ->> 'email') in (select email from officers));

drop policy if exists response_vehicles_delete_officers on response_vehicles;
create policy response_vehicles_delete_officers
  on response_vehicles for delete
  using ((auth.jwt() ->> 'email') in (select email from officers));

-- officers
drop policy if exists officers_read_self_or_admin on officers;
create policy officers_read_self_or_admin
  on officers for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email') or current_user_is_admin());

drop policy if exists officers_admin_insert on officers;
create policy officers_admin_insert
  on officers for insert
  with check (exists (
    select 1 from officers o
    where o.email = (auth.jwt() ->> 'email') and o.is_admin = true
  ));

drop policy if exists officers_admin_update on officers;
create policy officers_admin_update
  on officers for update
  using (exists (
    select 1 from officers o
    where o.email = (auth.jwt() ->> 'email') and o.is_admin = true
  ));

drop policy if exists officers_admin_delete on officers;
create policy officers_admin_delete
  on officers for delete
  using (exists (
    select 1 from officers o
    where o.email = (auth.jwt() ->> 'email') and o.is_admin = true
  ));

-- activity_log: čtení jen pro officery. Zapisuje výhradně trigger log_activity().
drop policy if exists activity_log_read_officers on activity_log;
create policy activity_log_read_officers
  on activity_log for select
  using ((auth.jwt() ->> 'email') in (select email from officers));

-- editors (nepoužívá se)
drop policy if exists "users can read own editor row" on editors;
create policy "users can read own editor row"
  on editors for select
  using (auth.uid() = user_id);


-- 4) STORAGE BUCKET NA FOTKY
-- --------------------------
-- Bucket "vehicles": veřejné čtení, nahrávat / měnit / mazat smí jen officer.
-- (V živé DB zbyly ještě staré politiky pro nepoužívaný bucket "vehicle-images";
-- appka je nepoužívá, proto tady nejsou.)

insert into storage.buckets (id, name, public)
values ('vehicles', 'vehicles', true)
on conflict (id) do nothing;

drop policy if exists "Public can read vehicle images" on storage.objects;
create policy "Public can read vehicle images"
  on storage.objects for select
  using (bucket_id = 'vehicles');

drop policy if exists "Officers can upload vehicle images" on storage.objects;
create policy "Officers can upload vehicle images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'vehicles'
    and (auth.jwt() ->> 'email') in (select email from officers)
  );

drop policy if exists "Officers can update vehicle images" on storage.objects;
create policy "Officers can update vehicle images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'vehicles'
    and (auth.jwt() ->> 'email') in (select email from officers)
  );

drop policy if exists "Officers can delete vehicle images" on storage.objects;
create policy "Officers can delete vehicle images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'vehicles'
    and (auth.jwt() ->> 'email') in (select email from officers)
  );


-- 5) REALTIME
-- -----------
-- Když jeden officer přidá / upraví / smaže záznam, všechny otevřené prohlížeče se aktualizují.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'vehicles') then
    alter publication supabase_realtime add table vehicles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'response_vehicles') then
    alter publication supabase_realtime add table response_vehicles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'activity_log') then
    alter publication supabase_realtime add table activity_log;
  end if;
end $$;


-- =====================================================
-- HOTOVO.
--
-- Další kroky:
--   1) Přidej sám sebe jako prvního admina (jinak se do appky nedostaneš):
--        insert into officers (email, display_name, is_admin, rank)
--        values ('tvuj@email.cz', 'Tvoje jméno', true, 'CO')
--        on conflict (email) do nothing;
--   2) Spusť 02-seed.sql (úvodní vozidla), pak 05, 06 (část 1), 07 a 08.
--   3) V appce vlož Project URL + anon key do config.js
--      (Settings → API).
-- =====================================================
