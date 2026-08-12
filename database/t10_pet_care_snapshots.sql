-- =====================================================
-- PawPal T10
-- Snapshot pet care notes onto bookings for assigned sitters
--
-- Sitters must not query public.pets.
-- They only see care notes copied onto their assigned bookings.
-- =====================================================

alter table public.bookings
  add column if not exists pet_medical_notes_snapshot text
    check (
      pet_medical_notes_snapshot is null
      or char_length(pet_medical_notes_snapshot) <= 1000
    );

alter table public.bookings
  add column if not exists pet_behaviour_notes_snapshot text
    check (
      pet_behaviour_notes_snapshot is null
      or char_length(pet_behaviour_notes_snapshot) <= 1000
    );

alter table public.bookings
  add column if not exists pet_care_notes_snapshot text
    check (
      pet_care_notes_snapshot is null
      or char_length(pet_care_notes_snapshot) <= 1000
    );

-- =====================================================
-- Populate care-note snapshots during booking creation
-- =====================================================

create or replace function public.prepare_pawpal_booking()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  selected_pet_name text;
  selected_medical_notes text;
  selected_behaviour_notes text;
  selected_care_notes text;
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

  select
    trim(pets.name),
    nullif(trim(pets.medical_notes), ''),
    nullif(trim(pets.behaviour_notes), ''),
    nullif(trim(pets.care_notes), '')
  into
    selected_pet_name,
    selected_medical_notes,
    selected_behaviour_notes,
    selected_care_notes
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
  new.pet_medical_notes_snapshot := selected_medical_notes;
  new.pet_behaviour_notes_snapshot := selected_behaviour_notes;
  new.pet_care_notes_snapshot := selected_care_notes;
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

-- =====================================================
-- Keep care-note snapshots immutable after insert
-- (preserves demo payment / refund behaviour)
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

  -- Original booking details remain immutable.
  if new.owner_id is distinct from old.owner_id
    or new.sitter_id is distinct from old.sitter_id
    or new.pet_name_snapshot is distinct from old.pet_name_snapshot
    or new.pet_medical_notes_snapshot
      is distinct from old.pet_medical_notes_snapshot
    or new.pet_behaviour_notes_snapshot
      is distinct from old.pet_behaviour_notes_snapshot
    or new.pet_care_notes_snapshot
      is distinct from old.pet_care_notes_snapshot
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

  if current_actor = old.owner_id then

    -- Secure demo payment transition.
    if new.payment_status is distinct from old.payment_status
      and new.status is not distinct from old.status
    then
      if old.status = 'accepted'
        and old.payment_status = 'unpaid'
        and new.payment_status = 'demo_paid'
      then
        null;
      else
        raise exception 'This payment status change is not allowed.';
      end if;

    -- Owner booking cancellation.
    elsif new.status is distinct from old.status then
      if new.status <> 'cancelled'
        or old.status not in ('pending', 'accepted')
      then
        raise exception 'The owner cannot make this booking status change.';
      end if;

      if old.payment_status = 'demo_paid' then
        new.payment_status := 'demo_refunded';
      else
        new.payment_status := old.payment_status;
      end if;

    else
      new.payment_status := old.payment_status;
    end if;

  elsif current_actor = old.sitter_id then

    if old.status = 'pending'
      and new.status in ('accepted', 'declined')
    then
      null;

    elsif old.status = 'accepted'
      and new.status = 'completed'
    then
      null;

    elsif new.status is distinct from old.status then
      raise exception 'The sitter cannot make this booking status change.';
    end if;

    new.payment_status := old.payment_status;

  else
    raise exception 'You do not have permission to update this booking.';
  end if;

  new.updated_at := now();

  return new;
end;
$$;
