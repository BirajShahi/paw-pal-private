-- =====================================================
-- PawPal T07A
-- Pet profiles and Row Level Security
-- =====================================================

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),

  owner_id uuid not null
    references auth.users(id)
    on delete cascade,

  name text not null
    check (
      char_length(trim(name)) between 2 and 60
    ),

  species text not null
    check (
      char_length(trim(species)) between 2 and 40
    ),

  breed text
    check (
      breed is null
      or char_length(trim(breed)) <= 80
    ),

  age_years numeric(4, 1)
    check (
      age_years is null
      or age_years between 0 and 100
    ),

  size text
    check (
      size is null
      or size in ('small', 'medium', 'large')
    ),

  coat_type text
    check (
      coat_type is null
      or char_length(trim(coat_type)) <= 80
    ),

  medical_notes text
    check (
      medical_notes is null
      or char_length(medical_notes) <= 1000
    ),

  behaviour_notes text
    check (
      behaviour_notes is null
      or char_length(behaviour_notes) <= 1000
    ),

  care_notes text
    check (
      care_notes is null
      or char_length(care_notes) <= 1000
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Improves queries that retrieve pets for one owner.
create index if not exists pets_owner_id_index
  on public.pets(owner_id);

-- Give authenticated PawPal users the required API permissions.
grant select, insert, update, delete
  on table public.pets
  to authenticated;

-- Activate Row Level Security.
alter table public.pets enable row level security;

-- Remove old versions so the script can safely be rerun.
drop policy if exists
  "Owners can view their own pets"
  on public.pets;

drop policy if exists
  "Owners can create their own pets"
  on public.pets;

drop policy if exists
  "Owners can update their own pets"
  on public.pets;

drop policy if exists
  "Owners can delete their own pets"
  on public.pets;

-- Owners can only read pets belonging to their account.
create policy "Owners can view their own pets"
on public.pets
for select
to authenticated
using (
  (select auth.uid()) = owner_id
);

-- Owners can only create pets using their own user ID.
create policy "Owners can create their own pets"
on public.pets
for insert
to authenticated
with check (
  (select auth.uid()) = owner_id
);

-- Owners can only update pets belonging to their account.
-- The owner_id cannot be changed to another user's ID.
create policy "Owners can update their own pets"
on public.pets
for update
to authenticated
using (
  (select auth.uid()) = owner_id
)
with check (
  (select auth.uid()) = owner_id
);

-- Owners can only delete pets belonging to their account.
create policy "Owners can delete their own pets"
on public.pets
for delete
to authenticated
using (
  (select auth.uid()) = owner_id
);

-- =====================================================
-- Automatically maintain updated_at
-- =====================================================

create or replace function public.update_pawpal_pet_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists
  update_pawpal_pet_timestamp_trigger
  on public.pets;

create trigger update_pawpal_pet_timestamp_trigger
before update on public.pets
for each row
execute function public.update_pawpal_pet_timestamp();