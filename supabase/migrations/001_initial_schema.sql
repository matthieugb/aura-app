-- 001_initial_schema.sql

-- User credits tracking
create table public.user_credits (
  id uuid references auth.users primary key,
  free_photos_used_today int default 0 not null,
  free_photos_reset_at date default current_date not null,
  animations_used_this_month int default 0 not null,
  animations_reset_at date default date_trunc('month', current_date) not null,
  is_premium boolean default false not null,
  created_at timestamptz default now() not null
);

-- Generation history
create table public.generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  background_id text not null,
  result_url text,
  animation_url text,
  status text default 'pending' not null check (status in ('pending', 'processing', 'done', 'error')),
  created_at timestamptz default now() not null
);

-- Backgrounds catalog
create table public.backgrounds (
  id text primary key,
  name text not null,
  category text not null check (category in ('studio', 'nature', 'urban', 'luxury')),
  storage_path text not null,
  is_premium boolean default false not null,
  sort_order int default 0 not null
);

-- Row Level Security
alter table public.user_credits enable row level security;
alter table public.generations enable row level security;
alter table public.backgrounds enable row level security;

-- Policies
create policy "Users read own credits"
  on public.user_credits for select
  using (auth.uid() = id);

create policy "Users read own generations"
  on public.generations for select
  using (auth.uid() = user_id);

create policy "Users insert own generations"
  on public.generations for insert
  with check (auth.uid() = user_id);

create policy "Anyone reads backgrounds"
  on public.backgrounds for select
  using (true);

-- Seed backgrounds
insert into public.backgrounds (id, name, category, storage_path, is_premium, sort_order) values
  ('golden-hour', 'Golden Hour', 'nature', 'backgrounds/golden-hour.jpg', false, 1),
  ('forest', 'Forest', 'nature', 'backgrounds/forest.jpg', false, 2),
  ('night-city', 'Night City', 'urban', 'backgrounds/night-city.jpg', false, 3),
  ('studio', 'Studio', 'studio', 'backgrounds/studio.jpg', true, 4),
  ('beach', 'Sunset Beach', 'nature', 'backgrounds/beach.jpg', true, 5),
  ('blue-hour', 'Blue Hour', 'urban', 'backgrounds/blue-hour.jpg', true, 6),
  ('marble', 'Marble', 'luxury', 'backgrounds/marble.jpg', true, 7),
  ('terracotta', 'Terracotta', 'luxury', 'backgrounds/terracotta.jpg', true, 8);
