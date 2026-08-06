-- =====================================================
-- PawPal T08C
-- Services offered by individual pet sitters/providers
-- =====================================================

create table if not exists public.sitter_services (
  id uuid primary key default gen_random_uuid(),

  sitter_id uuid not null
    references public.profiles(id)
    on delete cascade,

  service_id uuid not null
    references public.services(id)
    on delete restrict,

  price numeric(8, 2) not null
    check (
      price > 0
      and price <= 1000
    ),

  estimated_duration_minutes integer
    check (
      estimated_duration_minutes is null
      or estimated_duration_minutes between 15 and 1440
    ),

  service_notes text
    check (
      service_notes is null
      or char_length(trim(service_notes)) <= 500
    ),

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint sitter_services_unique_service
    unique (sitter_id, service_id)
);

create index if not exists sitter_services_sitter_id_index
  on public.sitter_services(sitter_id);

create index if not exists sitter_services_service_id_index
  on public.sitter_services(service_id);

create index if not exists sitter_services_active_index
  on public.sitter_services(is_active);

-- =====================================================
-- Permissions and Row Level Security
-- =====================================================

grant select, insert, update, delete
  on table public.sitter_services
  to authenticated;

alter table public.sitter_services enable row level security;

drop policy if exists
  "Authenticated users can view active sitter services"
  on public.sitter_services;

drop policy if exists
  "Sitters can view their own services"
  on public.sitter_services;

drop policy if exists
  "Sitters can create their own services"
  on public.sitter_services;

drop policy if exists
  "Sitters can update their own services"
  on public.sitter_services;

drop policy if exists
  "Sitters can delete their own services"
  on public.sitter_services;

-- Owners and sitters can view active service offerings.
create policy "Authenticated users can view active sitter services"
on public.sitter_services
for select
to authenticated
using (
  is_active = true
);

-- Sitters can also view their own inactive offerings.
create policy "Sitters can view their own services"
on public.sitter_services
for select
to authenticated
using (
  (select auth.uid()) = sitter_id
);

-- Only a signed-in sitter can create an offering for their own account.
create policy "Sitters can create their own services"
on public.sitter_services
for insert
to authenticated
with check (
  (select auth.uid()) = sitter_id
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'sitter'
  )
  and exists (
    select 1
    from public.services
    where services.id = service_id
      and services.is_active = true
  )
);

-- Sitters can update only their own offerings.
create policy "Sitters can update their own services"
on public.sitter_services
for update
to authenticated
using (
  (select auth.uid()) = sitter_id
)
with check (
  (select auth.uid()) = sitter_id
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'sitter'
  )
);

-- Sitters can delete only their own offerings.
create policy "Sitters can delete their own services"
on public.sitter_services
for delete
to authenticated
using (
  (select auth.uid()) = sitter_id
);

-- =====================================================
-- Automatically maintain updated_at
-- =====================================================

create or replace function public.update_pawpal_sitter_service_timestamp()
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
  update_pawpal_sitter_service_timestamp_trigger
  on public.sitter_services;

create trigger update_pawpal_sitter_service_timestamp_trigger
before update on public.sitter_services
for each row
execute function public.update_pawpal_sitter_service_timestamp();