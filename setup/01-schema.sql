-- =====================================================
-- SASP TEU Vehicle Database — Supabase Schema
-- =====================================================
-- Run this in the Supabase SQL Editor (Database → SQL Editor → New query)
-- Creates: vehicles table, officers table, RLS policies, storage bucket
-- =====================================================

-- 1) VEHICLES TABLE
-- ------------------
-- Stores all suspect vehicles and their response tiers.
create table if not exists vehicles (
  id          text primary key,
  vehicle     text not null,
  tier        text not null check (tier in ('S+', 'S', 'A+', 'A')),
  responses   jsonb not null default '[]'::jsonb,
  notes       text default '',
  image       text,  -- can be a path in /vehicles or a Supabase Storage URL
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  updated_by  text  -- officer email of last editor
);

-- index for fast tier filtering
create index if not exists vehicles_tier_idx on vehicles (tier);

-- auto-update updated_at on row change
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists vehicles_updated_at on vehicles;
create trigger vehicles_updated_at
  before update on vehicles
  for each row execute function set_updated_at();


-- 2) OFFICERS TABLE
-- ------------------
-- Stores which authenticated users have edit rights.
-- Only emails listed here can write to vehicles table.
create table if not exists officers (
  email       text primary key,
  display_name text,
  is_admin    boolean default false,  -- admins can manage other officers
  created_at  timestamptz default now()
);

-- IMPORTANT: Add your own email here BEFORE enabling RLS.
-- You can re-run this section anytime to add more officers.
-- Replace the email below with YOURS first:
insert into officers (email, display_name, is_admin)
values ('your-email@example.com', 'TEU Admin', true)
on conflict (email) do nothing;


-- 3) ROW-LEVEL SECURITY (RLS)
-- ----------------------------
-- Vehicles: everyone (including anon visitors) can read.
-- Only authenticated users listed in `officers` can insert/update/delete.

alter table vehicles enable row level security;

-- Public read access (anyone can see the tier list)
drop policy if exists "Public can read vehicles" on vehicles;
create policy "Public can read vehicles"
  on vehicles for select
  using (true);

-- Authenticated officers can insert
drop policy if exists "Officers can insert vehicles" on vehicles;
create policy "Officers can insert vehicles"
  on vehicles for insert
  to authenticated
  with check (
    auth.jwt() ->> 'email' in (select email from officers)
  );

-- Authenticated officers can update
drop policy if exists "Officers can update vehicles" on vehicles;
create policy "Officers can update vehicles"
  on vehicles for update
  to authenticated
  using (
    auth.jwt() ->> 'email' in (select email from officers)
  );

-- Authenticated officers can delete
drop policy if exists "Officers can delete vehicles" on vehicles;
create policy "Officers can delete vehicles"
  on vehicles for delete
  to authenticated
  using (
    auth.jwt() ->> 'email' in (select email from officers)
  );

-- Officers table: only admins can manage officer list
alter table officers enable row level security;

drop policy if exists "Anyone authenticated can read officers" on officers;
create policy "Anyone authenticated can read officers"
  on officers for select
  to authenticated
  using (true);

drop policy if exists "Admins can manage officers" on officers;
create policy "Admins can manage officers"
  on officers for all
  to authenticated
  using (
    exists (
      select 1 from officers o
      where o.email = auth.jwt() ->> 'email' and o.is_admin = true
    )
  );


-- 4) STORAGE BUCKET FOR VEHICLE IMAGES
-- -------------------------------------
-- Bucket name: "vehicles"
-- Public read, officer-only upload/delete.

insert into storage.buckets (id, name, public)
values ('vehicles', 'vehicles', true)
on conflict (id) do nothing;

-- Storage policies
drop policy if exists "Public can read vehicle images" on storage.objects;
create policy "Public can read vehicle images"
  on storage.objects for select
  using (bucket_id = 'vehicles');

drop policy if exists "Officers can upload vehicle images" on storage.objects;
create policy "Officers can upload vehicle images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'vehicles'
    and auth.jwt() ->> 'email' in (select email from officers)
  );

drop policy if exists "Officers can update vehicle images" on storage.objects;
create policy "Officers can update vehicle images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'vehicles'
    and auth.jwt() ->> 'email' in (select email from officers)
  );

drop policy if exists "Officers can delete vehicle images" on storage.objects;
create policy "Officers can delete vehicle images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'vehicles'
    and auth.jwt() ->> 'email' in (select email from officers)
  );


-- 5) REALTIME
-- -----------
-- Enable realtime broadcasts for the vehicles table.
-- When one officer adds/edits/deletes, all open browsers update instantly.
alter publication supabase_realtime add table vehicles;


-- =====================================================
-- DONE.
--
-- Next steps:
--   1) Run 02-seed.sql to populate with 57 starter vehicles
--   2) In your app, copy your Project URL + anon key from
--      Settings → API and paste them into config.js
--   3) Add officer emails to the `officers` table:
--        insert into officers (email, display_name)
--        values ('officer@example.com', 'Officer Name');
-- =====================================================
