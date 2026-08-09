-- =====================================================
-- PawPal T10F1
-- Secure demonstration payment action
--
-- This does NOT process real money.
-- No card or financial information is stored.
-- =====================================================


-- =====================================================
-- Restrict normal authenticated updates to booking status
-- =====================================================

-- Remove the previous table-wide UPDATE permission.
revoke update
  on table public.bookings
  from authenticated;

-- Flutter booking actions only need to modify status directly.
grant update (status)
  on table public.bookings
  to authenticated;


-- =====================================================
-- Update booking trigger for demo refund behaviour
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

  -- Original booking details are immutable.
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

  -- Foreign-key deletion actions may clear these references.
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

    -- The owner may only change status to cancelled from
    -- pending or accepted.
    if new.status is distinct from old.status then
      if new.status <> 'cancelled'
        or old.status not in ('pending', 'accepted')
      then
        raise exception 'The owner cannot make this booking status change.';
      end if;

      -- Demonstration refund:
      -- If a demo-paid booking is cancelled, automatically
      -- record it as demo refunded.
      if old.payment_status = 'demo_paid' then
        new.payment_status := 'demo_refunded';
      else
        new.payment_status := old.payment_status;
      end if;

    else
      -- A normal owner update may not change payment status.
      new.payment_status := old.payment_status;
    end if;

  elsif current_actor = old.sitter_id then

    -- Sitters may accept or decline pending bookings.
    if old.status = 'pending'
      and new.status in ('accepted', 'declined')
    then
      null;

    -- Sitters may complete accepted bookings.
    elsif old.status = 'accepted'
      and new.status = 'completed'
    then
      null;

    elsif new.status is distinct from old.status then
      raise exception 'The sitter cannot make this booking status change.';
    end if;

    -- Sitters cannot modify payment status.
    new.payment_status := old.payment_status;

  else
    raise exception 'You do not have permission to update this booking.';
  end if;

  new.updated_at := now();

  return new;
end;
$$;


-- =====================================================
-- Demo payment RPC
-- =====================================================

create or replace function public.demo_pay_booking(
  p_booking_id uuid
)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_actor uuid;
  paid_booking public.bookings;
begin
  current_actor := auth.uid();

  if current_actor is null then
    raise exception 'Authentication is required.';
  end if;

  -- Only pet-owner accounts may use the demo payment action.
  if not exists (
    select 1
    from public.profiles
    where profiles.id = current_actor
      and profiles.role = 'owner'
  ) then
    raise exception 'Only pet-owner accounts can make demo payments.';
  end if;

  -- Payment is permitted only for:
  -- - this authenticated owner's booking
  -- - an accepted booking
  -- - an unpaid booking
  update public.bookings
  set payment_status = 'demo_paid'
  where bookings.id = p_booking_id
    and bookings.owner_id = current_actor
    and bookings.status = 'accepted'
    and bookings.payment_status = 'unpaid'
  returning *
  into paid_booking;

  if not found then

    -- Avoid revealing another user's booking.
    if not exists (
      select 1
      from public.bookings
      where bookings.id = p_booking_id
        and bookings.owner_id = current_actor
    ) then
      raise exception 'The booking is unavailable.';
    end if;

    if exists (
      select 1
      from public.bookings
      where bookings.id = p_booking_id
        and bookings.owner_id = current_actor
        and bookings.payment_status = 'demo_paid'
    ) then
      raise exception 'This booking has already been demo paid.';
    end if;

    if exists (
      select 1
      from public.bookings
      where bookings.id = p_booking_id
        and bookings.owner_id = current_actor
        and bookings.payment_status = 'demo_refunded'
    ) then
      raise exception 'This booking has already been demo refunded.';
    end if;

    raise exception 'Only accepted bookings can be demo paid.';
  end if;

  return paid_booking;
end;
$$;


-- =====================================================
-- Function permissions
-- =====================================================

revoke all
  on function public.demo_pay_booking(uuid)
  from public;

revoke all
  on function public.demo_pay_booking(uuid)
  from anon;

grant execute
  on function public.demo_pay_booking(uuid)
  to authenticated;