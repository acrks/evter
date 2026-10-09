-- Evter's first durable model: events own their members, plans, and money.
-- This migration is intentionally provider-neutral: future travel/activity APIs attach
-- to these records rather than becoming the source of truth.

create type public.event_role as enum ('member', 'admin', 'super_admin');
create type public.event_stage as enum ('setup', 'voting', 'finalized', 'planning', 'completed');
create type public.poll_kind as enum ('destination', 'date');
create type public.rsvp_status as enum ('going', 'not_going', 'maybe');
create type public.payment_status as enum ('unpaid', 'paid', 'waived');

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  hometown text,
  bio text,
  relationship_to_honoree text,
  phone text,
  show_phone boolean not null default false,
  show_email boolean not null default false,
  created_at timestamptz not null default now()
);

-- This table is deliberately not writable through the browser. It is the small,
-- internal support escape hatch for the MVP's Party Down operators.
create table public.platform_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  granted_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  honoree_name text not null,
  destination text,
  theme text,
  stage public.event_stage not null default 'setup',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  finalized_at timestamptz
);

create table public.event_members (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.event_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  email text,
  phone text,
  proposed_role public.event_role not null default 'member',
  token text not null unique default encode(gen_random_bytes(18), 'hex'),
  expires_at timestamptz not null default now() + interval '14 days',
  accepted_at timestamptz,
  check (email is not null or phone is not null)
);

create table public.poll_options (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  kind public.poll_kind not null,
  label text not null,
  option_date date,
  created_at timestamptz not null default now(),
  unique (event_id, kind, label)
);

create table public.poll_votes (
  option_id uuid not null references public.poll_options(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (option_id, user_id)
);

create table public.travel_plans (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check (mode in ('flight', 'train', 'drive', 'other')),
  arrival_at timestamptz,
  departure_at timestamptz,
  details text,
  carpool_seats integer check (carpool_seats >= 0),
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create table public.accommodations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null unique references public.events(id) on delete cascade,
  name text not null,
  address text,
  bedrooms integer,
  bathrooms numeric(3,1),
  amenities text[] not null default '{}',
  total_cost numeric(10,2),
  notes text
);

create table public.supply_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  name text not null,
  details text,
  assigned_to uuid references public.profiles(id) on delete set null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  title text not null,
  starts_at timestamptz,
  location text,
  cost_per_person numeric(10,2),
  notes text,
  created_by uuid not null references public.profiles(id)
);

create table public.activity_rsvps (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.rsvp_status not null default 'maybe',
  reason text,
  primary key (activity_id, user_id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  title text not null,
  amount numeric(10,2) not null check (amount >= 0),
  due_date date,
  paid_by uuid references public.profiles(id) on delete set null,
  source_type text not null check (source_type in ('accommodation', 'activity', 'dinner', 'supply', 'other')),
  source_id uuid,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.expense_assignments (
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(10,2) not null check (amount >= 0),
  status public.payment_status not null default 'unpaid',
  paid_at timestamptz,
  primary key (expense_id, user_id)
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1), 'New member'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.add_event_creator_as_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.event_members (event_id, user_id, role)
  values (new.id, new.created_by, 'admin');
  return new;
end;
$$;

create trigger on_event_created
  after insert on public.events
  for each row execute procedure public.add_event_creator_as_admin();

create or replace function public.is_event_member(target_event_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.event_members where event_id = target_event_id and user_id = auth.uid());
$$;

create or replace function public.is_event_admin(target_event_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
    or exists (select 1 from public.event_members where event_id = target_event_id and user_id = auth.uid() and role in ('admin', 'super_admin'));
$$;

alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.invitations enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;
alter table public.travel_plans enable row level security;
alter table public.accommodations enable row level security;
alter table public.supply_items enable row level security;
alter table public.activities enable row level security;
alter table public.activity_rsvps enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_assignments enable row level security;

create policy "authenticated people can read profiles" on public.profiles for select to authenticated using (true);
create policy "people update only their profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "people create only their profile" on public.profiles for insert to authenticated with check (id = auth.uid());

create policy "members read their events" on public.events for select to authenticated using (public.is_event_member(id));
create policy "people create events" on public.events for insert to authenticated with check (created_by = auth.uid());
create policy "admins update events" on public.events for update to authenticated using (public.is_event_admin(id));
create policy "members read memberships" on public.event_members for select to authenticated using (public.is_event_member(event_id));
create policy "admins manage memberships" on public.event_members for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));

create policy "admins manage invitations" on public.invitations for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "members read poll options" on public.poll_options for select to authenticated using (public.is_event_member(event_id));
create policy "admins manage poll options" on public.poll_options for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "members vote privately" on public.poll_votes for select to authenticated using (user_id = auth.uid());
create policy "members cast their own votes" on public.poll_votes for insert to authenticated with check (user_id = auth.uid() and exists (select 1 from public.poll_options p where p.id = option_id and public.is_event_member(p.event_id)));
create policy "members withdraw their own votes" on public.poll_votes for delete to authenticated using (user_id = auth.uid());

create policy "members read travel" on public.travel_plans for select to authenticated using (public.is_event_member(event_id));
create policy "members manage their travel" on public.travel_plans for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_event_member(event_id));
create policy "members read lodging" on public.accommodations for select to authenticated using (public.is_event_member(event_id));
create policy "admins manage lodging" on public.accommodations for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "members read supplies" on public.supply_items for select to authenticated using (public.is_event_member(event_id));
create policy "members claim supplies" on public.supply_items for update to authenticated using (public.is_event_member(event_id)) with check (public.is_event_member(event_id));
create policy "admins create supplies" on public.supply_items for insert to authenticated with check (public.is_event_admin(event_id));
create policy "members read activities" on public.activities for select to authenticated using (public.is_event_member(event_id));
create policy "admins manage activities" on public.activities for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "members manage their RSVPs" on public.activity_rsvps for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "members read expenses" on public.expenses for select to authenticated using (public.is_event_member(event_id));
create policy "admins manage expenses" on public.expenses for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "members read their allocations" on public.expense_assignments for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.expenses e where e.id = expense_id and public.is_event_admin(e.event_id)));
create policy "admins manage allocations" on public.expense_assignments for all to authenticated using (exists (select 1 from public.expenses e where e.id = expense_id and public.is_event_admin(e.event_id))) with check (exists (select 1 from public.expenses e where e.id = expense_id and public.is_event_admin(e.event_id)));
