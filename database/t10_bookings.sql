-- =====================================================
-- PawPal T10A
-- Secure owner-to-sitter service bookings
-- =====================================================

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),

  owner_id uuid not null
    references public.profiles(id)
    on delete cascade,

  -- May become null if the pet is removed later.
  -- The pet name snapshot preserves booking information.
  pet_id uuid
    references public.pets(id)
    on delete set null,

  sitter_id uuid not null
    references public.profiles(id)
    on delete restrict,

  -- May become null if the sitter removes the offering later.
  -- Service snapshots preserve the original booking details.
  sitter_service_id uuid
    references public.sitter_services(id)
    on delete set null,

  pet_name_snapshot text not null
    check (
      char_length(trim(pet_name_snapshot)) between 2 and 60
    ),

  service_code_snapshot text not null
    check (
      service_code_snapshot ~ '^[a-z0-9_]+$'
      and char_length(service_code_snapshot) between 2 and 60
    ),

  service_name_snapshot text not null
    check (
      char_length(trim(service_name_snapshot)) between 2 and 80
    ),

  price_snapshot numeric(8, 2) not null
    check (
      price_snapshot > 0
      and price_snapshot <= 1000
    ),

  estimated_duration_minutes integer
    check (
      estimated_duration_minutes is null
      or estimated_duration_minutes between 15 and 1440
    ),

  requested_start timestamptz not null,

  owner_notes text
    check (
      owner_notes is null
      or char_length(trim(owner_notes)) between 2 and 1000
    ),

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'accepted',
        'declined',
        'cancelled',
        'completed'
      )
    ),

  -- This is for the later demonstration payment flow only.
  -- No real payment information is stored.
  payment_status text not null default 'unpaid'
    check (
      payment_status in (
        'unpaid',
        'demo_paid',
        'demo_refunded'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bookings_owner_id_index
  on public.bookings(owner_id);

create index if not exists bookings_sitter_id_index
  on public.bookings(sitter_id);

create index if not exists bookings_pet_id_index
  on public.bookings(pet_id);

create index if not exists bookings_requested_start_index
  on public.bookings(requested_start);

create index if not exists bookings_status_index
  on public.bookings(status);

-- =====================================================
-- Prepare and validate new bookings
-- =====================================================

create or replace function public.prepare_pawpal_booking()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  selected_pet_name text;
  selected_sitter_id uuid;
  selected_service_code text;
  selected_service_name text;
  selected_price numeric(8, 2);
  selected_duration integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if new.owner_id <> auth.uid() then
    raise exception 'Bookings can only be created for the signed-in owner.';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'owner'
  ) then
    raise exception 'Only owner accounts can create bookings.';
  end if;

  if new.pet_id is null then
    raise exception 'A pet must be selected.';
  end if;

  select trim(pets.name)
  into selected_pet_name
  from public.pets
  where pets.id = new.pet_id
    and pets.owner_id = new.owner_id;

  if not found then
    raise exception 'The selected pet is unavailable.';
  end if;

  if new.sitter_service_id is null then
    raise exception 'A sitter service must be selected.';
  end if;

  select
    sitter_services.sitter_id,
    services.code,
    services.name,
    sitter_services.price,
    sitter_services.estimated_duration_minutes
  into
    selected_sitter_id,
    selected_service_code,
    selected_service_name,
    selected_price,
    selected_duration
  from public.sitter_services
  join public.services
    on services.id = sitter_services.service_id
  join public.profiles sitter_profile
    on sitter_profile.id = sitter_services.sitter_id
  where sitter_services.id = new.sitter_service_id
    and sitter_services.is_active = true
    and services.is_active = true
    and sitter_profile.role = 'sitter';

  if not found then
    raise exception 'The selected service offering is unavailable.';
  end if;

  if new.requested_start <= now() then
    raise exception 'The booking date and time must be in the future.';
  end if;

  new.sitter_id := selected_sitter_id;
  new.pet_name_snapshot := selected_pet_name;
  new.service_code_snapshot := selected_service_code;
  new.service_name_snapshot := selected_service_name;
  new.price_snapshot := selected_price;
  new.estimated_duration_minutes := selected_duration;
  new.owner_notes := nullif(trim(new.owner_notes), '');

  -- Prevent the client from creating an already accepted, completed
  -- or paid booking.
  new.status := 'pending';
  new.payment_status := 'unpaid';

  return new;
end;
$$;

drop trigger if exists prepare_pawpal_booking_trigger
  on public.bookings;

create trigger prepare_pawpal_booking_trigger
before insert on public.bookings
for each row
execute function public.prepare_pawpal_booking();

-- =====================================================
-- Protect booking details and status transitions
-- =====================================================

create or replace function public.validate_pawpal_booking_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_actor uuid;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication is required.';
  end if;

  -- These original booking details cannot be changed.
  if new.owner_id is distinct from old.owner_id
    or new.sitter_id is distinct from old.sitter_id
    or new.pet_name_snapshot is distinct from old.pet_name_snapshot
    or new.service_code_snapshot is distinct from old.service_code_snapshot
    or new.service_name_snapshot is distinct from old.service_name_snapshot
    or new.price_snapshot is distinct from old.price_snapshot
    or new.estimated_duration_minutes
      is distinct from old.estimated_duration_minutes
    or new.requested_start is distinct from old.requested_start
    or new.owner_notes is distinct from old.owner_notes
    or new.created_at is distinct from old.created_at
  then
    raise exception 'Original booking details cannot be changed.';
  end if;

  -- Foreign-key deletion actions may set these references to null.
  if new.pet_id is distinct from old.pet_id
    and new.pet_id is not null
  then
    raise exception 'The booking pet cannot be changed.';
  end if;

  if new.sitter_service_id is distinct from old.sitter_service_id
    and new.sitter_service_id is not null
  then
    raise exception 'The booked service cannot be changed.';
  end if;

  -- Payment status will be handled by a separate demonstration
  -- payment action in a later ticket.
  if new.payment_status is distinct from old.payment_status then
    raise exception 'Payment status cannot be changed through this action.';
  end if;

  if current_actor = old.owner_id then
    -- Owners may cancel pending or accepted bookings.
    if new.status is distinct from old.status then
      if new.status <> 'cancelled'
        or old.status not in ('pending', 'accepted')
      then
        raise exception 'The owner cannot make this booking status change.';
      end if;
    end if;

  elsif current_actor = old.sitter_id then
    -- Sitters may accept or decline a pending booking.
    if old.status = 'pending'
      and new.status in ('accepted', 'declined')
    then
      null;

    -- Sitters may complete an accepted booking.
    elsif old.status = 'accepted'
      and new.status = 'completed'
    then
      null;

    elsif new.status is distinct from old.status then
      raise exception 'The sitter cannot make this booking status change.';
    end if;

  else
    raise exception 'You do not have permission to update this booking.';
  end if;

  new.updated_at := now();

  return new;
end;
$$;

drop trigger if exists validate_pawpal_booking_update_trigger
  on public.bookings;

create trigger validate_pawpal_booking_update_trigger
before update on public.bookings
for each row
execute function public.validate_pawpal_booking_update();

-- =====================================================
-- Permissions and Row Level Security
-- =====================================================

revoke all on table public.bookings from anon;
revoke all on table public.bookings from authenticated;

grant select, insert, update
  on table public.bookings
  to authenticated;

alter table public.bookings enable row level security;

drop policy if exists
  "Owners can view their bookings"
  on public.bookings;

drop policy if exists
  "Sitters can view assigned bookings"
  on public.bookings;

drop policy if exists
  "Owners can create bookings"
  on public.bookings;

drop policy if exists
  "Owners can update their bookings"
  on public.bookings;

drop policy if exists
  "Sitters can update assigned bookings"
  on public.bookings;

create policy "Owners can view their bookings"
on public.bookings
for select
to authenticated
using (
  (select auth.uid()) = owner_id
);

create policy "Sitters can view assigned bookings"
on public.bookings
for select
to authenticated
using (
  (select auth.uid()) = sitter_id
);

create policy "Owners can create bookings"
on public.bookings
for insert
to authenticated
with check (
  (select auth.uid()) = owner_id

  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'owner'
  )

  and exists (
    select 1
    from public.pets
    where pets.id = pet_id
      and pets.owner_id = (select auth.uid())
  )

  and exists (
    select 1
    from public.sitter_services
    join public.services
      on services.id = sitter_services.service_id
    where sitter_services.id = sitter_service_id
      and sitter_services.sitter_id = sitter_id
      and sitter_services.is_active = true
      and services.is_active = true
  )
);

create policy "Owners can update their bookings"
on public.bookings
for update
to authenticated
using (
  (select auth.uid()) = owner_id
)
with check (
  (select auth.uid()) = owner_id
);

create policy "Sitters can update assigned bookings"
on public.bookings
for update
to authenticated
using (
  (select auth.uid()) = sitter_id
)
with check (
  (select auth.uid()) = sitter_id
);

-- No delete policy is created.
-- Booking records are cancelled rather than manually deleted.