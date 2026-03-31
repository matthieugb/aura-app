-- 003_free_credit_on_signup.sql
-- Give 1 free credit to every new user on signup

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform add_credits(new.id, 1);
  return new;
end;
$$;

-- Drop trigger if it already exists (safe re-run)
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
