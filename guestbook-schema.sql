begin;
create table if not exists public.mimo_letters (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id),
 recipient text not null check(recipient in ('karyn','jinhee')),
 name text not null check(char_length(btrim(name)) between 1 and 24),
 message text not null check(char_length(btrim(message)) between 1 and 200),
 photo text check(photo is null or (octet_length(photo)<=80000 and photo ~ '^data:image/(webp|jpeg|png);base64,[A-Za-z0-9+/=]+$')),
 created_at timestamptz not null default now(), deleted_at timestamptz);
alter table public.mimo_letters enable row level security;
revoke all on public.mimo_letters from anon,authenticated;
grant select on public.mimo_letters to anon,authenticated;
grant insert(author_id,recipient,name,message,photo) on public.mimo_letters to authenticated;
grant update(deleted_at) on public.mimo_letters to authenticated;
create policy letters_read on public.mimo_letters for select using(deleted_at is null or author_id=auth.uid());
create policy letters_write on public.mimo_letters for insert to authenticated with check(author_id=auth.uid() and deleted_at is null);
create policy letters_remove on public.mimo_letters for update to authenticated using(author_id=auth.uid()) with check(author_id=auth.uid() and deleted_at is not null);
create index if not exists mimo_letters_recipient_date on public.mimo_letters(recipient,created_at desc);
create index if not exists mimo_letters_author_date on public.mimo_letters(author_id,created_at desc);
create or replace function public.mimo_limit_posts() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.author_id::text,0));
 if exists(select 1 from public.mimo_letters where author_id=new.author_id and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds' using errcode='P0001'; end if;
 if (select count(*) from public.mimo_letters where author_id=new.author_id and created_at>now()-interval '1 day')>=20 then raise exception 'Daily limit reached' using errcode='P0001'; end if;
 return new;
end; $$;
revoke all on function public.mimo_limit_posts() from public,anon,authenticated;
create trigger mimo_limit_posts before insert on public.mimo_letters for each row execute function public.mimo_limit_posts();
commit;