-- ChoreBloom 3.0 database setup
-- Run this entire script in Supabase Dashboard > SQL Editor.
-- Uses Supabase Auth. Do not expose a service_role key in your website.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Friend',
  created_at timestamptz not null default now()
);
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  invite_code uuid not null unique default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id,user_id)
);
create table if not exists public.chores (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 90),
  assigned_to uuid not null references auth.users(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  points int not null default 10 check (points between 1 and 100),
  is_done boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists chores_group_id_idx on public.chores(group_id);
create index if not exists group_members_user_id_idx on public.group_members(user_id);

create or replace function public.is_group_member(target_group uuid)
returns boolean language sql security definer stable set search_path=public
as $$ select exists(select 1 from public.group_members where group_id=target_group and user_id=auth.uid()); $$;

create or replace function public.join_group(invite_code_input uuid)
returns void language plpgsql security definer set search_path=public
as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  select id into target_id from public.groups where invite_code=invite_code_input;
  if target_id is null then raise exception 'That invite code was not found'; end if;
  insert into public.group_members(group_id,user_id,role) values(target_id,auth.uid(),'member')
  on conflict(group_id,user_id) do nothing;
end; $$;

create or replace function public.create_group(group_name_input text)
returns table(id uuid, name text, invite_code uuid)
language plpgsql security definer set search_path=public
as $$
declare new_group public.groups%rowtype;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  if char_length(trim(group_name_input)) not between 1 and 40 then raise exception 'Group name must be 1 to 40 characters'; end if;
  insert into public.groups(name,created_by) values(trim(group_name_input),auth.uid()) returning * into new_group;
  insert into public.group_members(group_id,user_id,role) values(new_group.id,auth.uid(),'admin');
  return query select new_group.id,new_group.name,new_group.invite_code;
end; $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
 insert into public.profiles(id,display_name)
 values(new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(new.email,'@',1),'Friend'))
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created_chorebloom on auth.users;
create trigger on_auth_user_created_chorebloom after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.chores enable row level security;

drop policy if exists "Profiles visible to group members" on public.profiles;
create policy "Profiles visible to group members" on public.profiles for select to authenticated
using (id=auth.uid() or exists(select 1 from public.group_members mine join public.group_members theirs on mine.group_id=theirs.group_id where mine.user_id=auth.uid() and theirs.user_id=profiles.id));
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

drop policy if exists "Members can view their groups" on public.groups;
create policy "Members can view their groups" on public.groups for select to authenticated using(public.is_group_member(id));
drop policy if exists "Authenticated users create groups" on public.groups;
create policy "Authenticated users create groups" on public.groups for insert to authenticated with check(created_by=auth.uid());
drop policy if exists "Group admins update groups" on public.groups;
create policy "Group admins update groups" on public.groups for update to authenticated using(exists(select 1 from public.group_members where group_id=id and user_id=auth.uid() and role='admin')) with check(exists(select 1 from public.group_members where group_id=id and user_id=auth.uid() and role='admin'));

drop policy if exists "Members view group membership" on public.group_members;
create policy "Members view group membership" on public.group_members for select to authenticated using(public.is_group_member(group_id));
drop policy if exists "Creator adds self as first admin" on public.group_members;
-- Membership rows are created only by the SECURITY DEFINER RPC functions below.
-- There is intentionally no direct INSERT policy for browser clients.
drop policy if exists "Admins remove group members" on public.group_members;
create policy "Admins remove group members" on public.group_members for delete to authenticated using(exists(select 1 from public.group_members admin_row where admin_row.group_id=group_id and admin_row.user_id=auth.uid() and admin_row.role='admin') or user_id=auth.uid());

drop policy if exists "Group members view chores" on public.chores;
create policy "Group members view chores" on public.chores for select to authenticated using(public.is_group_member(group_id));
drop policy if exists "Group members add chores" on public.chores;
create policy "Group members add chores" on public.chores for insert to authenticated with check(public.is_group_member(group_id) and created_by=auth.uid() and exists(select 1 from public.group_members where group_id=chores.group_id and user_id=chores.assigned_to));
drop policy if exists "Group members update chores" on public.chores;
create policy "Group members update chores" on public.chores for update to authenticated using(public.is_group_member(group_id)) with check(public.is_group_member(group_id));
drop policy if exists "Group admins delete chores" on public.chores;
create policy "Group admins delete chores" on public.chores for delete to authenticated using(exists(select 1 from public.group_members where group_id=chores.group_id and user_id=auth.uid() and role='admin'));

grant usage on schema public to authenticated;
grant select,update on public.profiles to authenticated;
grant select,insert,update on public.groups to authenticated;
grant select,delete on public.group_members to authenticated;
grant select,insert,update,delete on public.chores to authenticated;
grant execute on function public.join_group(uuid) to authenticated;
grant execute on function public.create_group(text) to authenticated;
grant execute on function public.is_group_member(uuid) to authenticated;

-- Optional: enable Realtime for the shared chore board:
alter publication supabase_realtime add table public.chores;
alter publication supabase_realtime add table public.group_members;
