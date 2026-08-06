-- =====================================================
-- PawPal T08A
-- Controlled service catalogue for owners, providers
-- and the future AI service recommender
-- =====================================================

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),

  -- Stable value used by Flutter and the AI recommender.
  code text not null unique
    check (
      code ~ '^[a-z0-9_]+$'
      and char_length(code) between 2 and 60
    ),

  name text not null unique
    check (
      char_length(trim(name)) between 2 and 80
    ),

  category text not null
    check (
      category in (
        'grooming',
        'walking',
        'home_care',
        'sitting'
      )
    ),

  description text not null
    check (
      char_length(trim(description)) between 10 and 500
    ),

  -- The main tasks normally included in this service.
  included_items text[] not null default array[]::text[],

  -- Keywords that can help the AI understand suitable situations.
  recommendation_tags text[] not null default array[]::text[],

  -- Some services can be recommended alongside a primary service.
  can_be_add_on boolean not null default false,

  is_active boolean not null default true,

  display_order integer not null default 0
    check (display_order >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists services_category_index
  on public.services(category);

create index if not exists services_display_order_index
  on public.services(display_order);

-- =====================================================
-- Security
-- =====================================================

alter table public.services enable row level security;

-- The client application may read services but cannot change
-- the controlled catalogue.
revoke all on table public.services from anon;

revoke insert, update, delete
  on table public.services
  from authenticated;

grant select
  on table public.services
  to authenticated;

drop policy if exists
  "Authenticated users can view active services"
  on public.services;

create policy "Authenticated users can view active services"
on public.services
for select
to authenticated
using (
  is_active = true
);

-- =====================================================
-- Automatically maintain updated_at
-- =====================================================

create or replace function public.update_pawpal_service_timestamp()
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
  update_pawpal_service_timestamp_trigger
  on public.services;

create trigger update_pawpal_service_timestamp_trigger
before update on public.services
for each row
execute function public.update_pawpal_service_timestamp();

-- =====================================================
-- Controlled PawPal service catalogue
-- Safe to rerun because each service uses a unique code
-- =====================================================

insert into public.services (
  code,
  name,
  category,
  description,
  included_items,
  recommendation_tags,
  can_be_add_on,
  display_order
)
values

(
  'full_grooming',
  'Full Grooming',
  'grooming',
  'A complete grooming service for pets that need cleaning, brushing, trimming and general coat maintenance.',
  array[
    'Wash and shampoo',
    'Blow-dry',
    'Full brushing',
    'Hair trimming',
    'Nail clipping',
    'Ear cleaning'
  ],
  array[
    'dirty coat',
    'long coat',
    'overgrown coat',
    'overgrown nails',
    'multiple grooming needs',
    'has not been groomed recently'
  ],
  false,
  10
),

(
  'wash_and_dry',
  'Wash and Dry',
  'grooming',
  'A basic cleaning service for pets that are dirty but do not require trimming or extensive coat treatment.',
  array[
    'Pet-safe shampoo',
    'Rinse',
    'Towel or blow-dry'
  ],
  array[
    'muddy',
    'dirty',
    'bad smell',
    'basic clean',
    'no haircut needed'
  ],
  false,
  20
),

(
  'wash_dry_and_brush',
  'Wash, Dry and Brush',
  'grooming',
  'A cleaning and brushing service for pets that need coat maintenance without a haircut.',
  array[
    'Pet-safe shampoo',
    'Rinse',
    'Blow-dry',
    'Thorough brushing'
  ],
  array[
    'dirty coat',
    'tangled coat',
    'light shedding',
    'brushing needed',
    'no haircut needed'
  ],
  false,
  30
),

(
  'deshedding_treatment',
  'De-shedding Treatment',
  'grooming',
  'A specialised brushing treatment that helps remove loose undercoat and reduce excessive shedding.',
  array[
    'Coat assessment',
    'De-shedding treatment',
    'Undercoat brushing',
    'Loose hair removal'
  ],
  array[
    'heavy shedding',
    'loose undercoat',
    'double coat',
    'seasonal shedding',
    'fur around home'
  ],
  true,
  40
),

(
  'hair_trim',
  'Hair Trim',
  'grooming',
  'A targeted coat trimming service for pets that need their fur shortened or tidied without a complete grooming package.',
  array[
    'Coat assessment',
    'Hair trimming',
    'Coat tidying'
  ],
  array[
    'long hair',
    'overgrown fur',
    'hair covering eyes',
    'tidy coat',
    'minor haircut'
  ],
  true,
  50
),

(
  'nail_clipping',
  'Nail Clipping',
  'grooming',
  'A focused nail-care service for pets with long or uncomfortable nails.',
  array[
    'Nail assessment',
    'Safe nail clipping'
  ],
  array[
    'overgrown nails',
    'long nails',
    'nails clicking',
    'difficulty walking',
    'nail care'
  ],
  true,
  60
),

(
  'ear_cleaning',
  'Ear Cleaning',
  'grooming',
  'A basic external ear-cleaning service for routine hygiene and grooming maintenance.',
  array[
    'External ear inspection',
    'Gentle external ear cleaning'
  ],
  array[
    'dirty ears',
    'routine ear care',
    'ear cleaning needed'
  ],
  true,
  70
),

(
  'puppy_grooming',
  'Puppy Grooming',
  'grooming',
  'A gentle introductory grooming experience designed for young dogs becoming familiar with grooming.',
  array[
    'Gentle wash',
    'Light dry',
    'Gentle brushing',
    'Grooming introduction'
  ],
  array[
    'puppy',
    'first groom',
    'young dog',
    'nervous puppy',
    'grooming introduction'
  ],
  false,
  80
),

(
  'senior_pet_grooming',
  'Senior Pet Grooming',
  'grooming',
  'A slower grooming service designed for older pets that may require extra care, rest breaks or gentle handling.',
  array[
    'Gentle wash',
    'Low-stress drying',
    'Gentle brushing',
    'Additional rest breaks'
  ],
  array[
    'senior pet',
    'older dog',
    'older cat',
    'arthritis',
    'limited mobility',
    'gentle handling'
  ],
  false,
  90
),

(
  'dog_walking',
  'Dog Walking',
  'walking',
  'A scheduled walking service that provides exercise, outdoor activity and basic supervision.',
  array[
    'Supervised walk',
    'Exercise',
    'Water break',
    'Basic walk update'
  ],
  array[
    'needs exercise',
    'high energy',
    'owner unavailable',
    'regular walk',
    'outdoor activity'
  ],
  false,
  100
),

(
  'home_visit',
  'Home Visit',
  'home_care',
  'A short visit to the owner’s home for feeding, checking wellbeing and completing basic care tasks.',
  array[
    'Wellbeing check',
    'Food and water',
    'Basic care tasks',
    'Owner update'
  ],
  array[
    'stay at home',
    'short visit',
    'feeding',
    'anxious outside home',
    'routine check'
  ],
  false,
  110
),

(
  'pet_sitting',
  'Pet Sitting',
  'sitting',
  'A longer care service where a provider supervises and cares for the pet while the owner is unavailable.',
  array[
    'Pet supervision',
    'Feeding',
    'Play and companionship',
    'Routine care',
    'Owner updates'
  ],
  array[
    'owner away',
    'day care',
    'companionship',
    'supervision',
    'cannot be left alone'
  ],
  false,
  120
),

(
  'overnight_care',
  'Overnight Care',
  'sitting',
  'An overnight pet-care service for pets that need supervision and companionship throughout the night.',
  array[
    'Overnight supervision',
    'Evening feeding',
    'Morning feeding',
    'Routine care',
    'Owner updates'
  ],
  array[
    'overnight',
    'owner travelling',
    'night supervision',
    'separation anxiety',
    'cannot stay alone'
  ],
  false,
  130
),

(
  'medication_assistance',
  'Medication Assistance',
  'home_care',
  'A support service for administering owner-provided routine medication according to written care instructions.',
  array[
    'Follow written instructions',
    'Routine medication assistance',
    'Medication update to owner'
  ],
  array[
    'medication',
    'scheduled medicine',
    'tablet',
    'routine treatment',
    'medicine assistance'
  ],
  true,
  140
)

on conflict (code)
do update set
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  included_items = excluded.included_items,
  recommendation_tags = excluded.recommendation_tags,
  can_be_add_on = excluded.can_be_add_on,
  is_active = true,
  display_order = excluded.display_order;