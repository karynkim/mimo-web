-- MiMO guest book: operator delete (run once in Supabase → SQL Editor)
-- 1) Change '여기에-관리자-코드' below to the code Karyn and Jinhee will use. Do not put the real code in this file in the repository.
-- 2) Run the whole script. Running it again replaces the code.
begin;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.mimo_admin (id int primary key default 1 check (id = 1), code_hash text not null);
insert into private.mimo_admin (id, code_hash)
values (1, extensions.crypt('여기에-관리자-코드', extensions.gen_salt('bf')))
on conflict (id) do update set code_hash = excluded.code_hash;

create or replace function public.mimo_admin_check(code text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from private.mimo_admin where code_hash = extensions.crypt(code, code_hash)) then return true; end if;
  perform pg_sleep(1);   -- slows down guessing
  return false;
end $$;

create or replace function public.mimo_admin_hide(letter_id uuid, code text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.mimo_admin_check(code) then return false; end if;
  update public.mimo_letters set deleted_at = now() where id = letter_id and deleted_at is null;
  return found;
end $$;

revoke all on function public.mimo_admin_check(text) from public;
revoke all on function public.mimo_admin_hide(uuid, text) from public;
grant execute on function public.mimo_admin_check(text) to anon, authenticated;
grant execute on function public.mimo_admin_hide(uuid, text) to anon, authenticated;
commit;
