-- Rituel — multiplayer backend schema (Supabase / PostgreSQL)
-- Paste this whole file into Supabase → SQL Editor → Run.

-- ------------------------------------------------------------------ profiles
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  username      text unique not null check (username ~ '^[a-z0-9_.]{3,24}$'),
  display_name  text default '',
  avatar_emoji  text default '🙂',
  friend_code   text unique not null default upper(substr(md5(random()::text), 1, 6)),
  level         int  default 1,
  xp            int  default 0,
  perfect_days  int  default 0,
  best_streak   int  default 0,
  avg_score     real default 0,
  updated_at    timestamptz default now()
);

-- Create the profile automatically at sign-up (username comes from the app's metadata).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  base text := lower(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)));
  candidate text;
begin
  base := regexp_replace(base, '[^a-z0-9_.]', '', 'g');
  if char_length(base) < 3 then base := base || 'user'; end if;
  base := left(base, 20);
  candidate := base;
  while exists (select 1 from public.profiles where username = candidate) loop
    candidate := base || floor(random() * 1000)::text;
  end loop;
  insert into public.profiles (id, username, display_name)
  values (new.id, candidate, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------------------------- friendships
create table if not exists public.friendships (
  id          bigint generated always as identity primary key,
  requester   uuid not null references public.profiles(id) on delete cascade,
  addressee   uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz default now(),
  unique (requester, addressee),
  check (requester <> addressee)
);

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

-- --------------------------------------------------------------- challenges
create table if not exists public.challenges (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  emoji        text default '⚔️',
  color        bigint,
  description  text default '',
  target       int default 1,
  unit         text default '',
  weekdays     int[] default '{1,2,3,4,5,6,7}',
  invite_code  text unique not null default upper(substr(md5(random()::text), 1, 6)),
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz default now()
);

create table if not exists public.challenge_members (
  challenge_id  uuid references public.challenges(id) on delete cascade,
  user_id       uuid references public.profiles(id) on delete cascade,
  joined_at     timestamptz default now(),
  primary key (challenge_id, user_id)
);

create table if not exists public.challenge_checkins (
  challenge_id  uuid references public.challenges(id) on delete cascade,
  user_id       uuid references public.profiles(id) on delete cascade,
  day           date not null,
  primary key (challenge_id, user_id, day)
);

create or replace function public.is_member(c uuid, u uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.challenge_members where challenge_id = c and user_id = u);
$$;

-- -------------------------------------------------------------- habit stats
create table if not exists public.habit_stats (
  user_id         uuid references public.profiles(id) on delete cascade,
  habit_id        text not null,
  name            text,
  emoji           text,
  color           bigint,
  current_streak  int default 0,
  best_streak     int default 0,
  score           real default 0,
  rate30          real default 0,
  total           int default 0,
  done_today      boolean default false,
  last7           text default '',
  challenge_id    uuid references public.challenges(id) on delete set null,
  is_public       boolean default true,
  updated_at      timestamptz default now(),
  primary key (user_id, habit_id)
);

-- ---------------------------------------------------------- row level security
alter table public.profiles            enable row level security;
alter table public.friendships         enable row level security;
alter table public.challenges          enable row level security;
alter table public.challenge_members   enable row level security;
alter table public.challenge_checkins  enable row level security;
alter table public.habit_stats         enable row level security;

-- Profiles: any signed-in user can look people up (needed to add friends); you edit only yours.
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Friendships: visible to both sides; you send as yourself; the addressee accepts; either side removes.
drop policy if exists "friendships read" on public.friendships;
create policy "friendships read" on public.friendships for select to authenticated
  using (auth.uid() in (requester, addressee));
drop policy if exists "friendships insert" on public.friendships;
create policy "friendships insert" on public.friendships for insert to authenticated
  with check (requester = auth.uid() and status = 'pending');
drop policy if exists "friendships accept" on public.friendships;
create policy "friendships accept" on public.friendships for update to authenticated
  using (addressee = auth.uid()) with check (addressee = auth.uid());
drop policy if exists "friendships delete" on public.friendships;
create policy "friendships delete" on public.friendships for delete to authenticated
  using (auth.uid() in (requester, addressee));

-- Challenges: readable by signed-in users (joining by invite code); creator manages.
drop policy if exists "challenges read" on public.challenges;
create policy "challenges read" on public.challenges for select to authenticated using (true);
drop policy if exists "challenges insert" on public.challenges;
create policy "challenges insert" on public.challenges for insert to authenticated
  with check (created_by = auth.uid());
drop policy if exists "challenges update" on public.challenges;
create policy "challenges update" on public.challenges for update to authenticated
  using (created_by = auth.uid());
drop policy if exists "challenges delete" on public.challenges;
create policy "challenges delete" on public.challenges for delete to authenticated
  using (created_by = auth.uid());

-- Members: members see each other; you join/leave as yourself.
drop policy if exists "members read" on public.challenge_members;
create policy "members read" on public.challenge_members for select to authenticated
  using (user_id = auth.uid() or public.is_member(challenge_id, auth.uid()));
drop policy if exists "members join" on public.challenge_members;
create policy "members join" on public.challenge_members for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "members leave" on public.challenge_members;
create policy "members leave" on public.challenge_members for delete to authenticated
  using (user_id = auth.uid());

-- Check-ins: visible to members; you write only yours, only in challenges you joined.
drop policy if exists "checkins read" on public.challenge_checkins;
create policy "checkins read" on public.challenge_checkins for select to authenticated
  using (public.is_member(challenge_id, auth.uid()));
drop policy if exists "checkins insert" on public.challenge_checkins;
create policy "checkins insert" on public.challenge_checkins for insert to authenticated
  with check (user_id = auth.uid() and public.is_member(challenge_id, auth.uid()));
drop policy if exists "checkins delete" on public.challenge_checkins;
create policy "checkins delete" on public.challenge_checkins for delete to authenticated
  using (user_id = auth.uid());

-- Habit stats: yours, friends' public ones, and those of fellow challenge members.
drop policy if exists "stats read" on public.habit_stats;
create policy "stats read" on public.habit_stats for select to authenticated
  using (
    user_id = auth.uid()
    or (is_public and public.are_friends(auth.uid(), user_id))
    or (challenge_id is not null and public.is_member(challenge_id, auth.uid()))
  );
drop policy if exists "stats insert" on public.habit_stats;
create policy "stats insert" on public.habit_stats for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "stats update" on public.habit_stats;
create policy "stats update" on public.habit_stats for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "stats delete" on public.habit_stats;
create policy "stats delete" on public.habit_stats for delete to authenticated
  using (user_id = auth.uid());
