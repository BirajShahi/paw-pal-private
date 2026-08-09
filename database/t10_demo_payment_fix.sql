-- =====================================================
-- PawPal T10F1b
-- Allow the secure demo payment RPC to perform the
-- controlled unpaid -> demo_paid transition.
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