-- 002_add_credits_balance.sql
-- Add user_id and balance columns for the credit system

-- Add columns (safe with IF NOT EXISTS)
alter table public.user_credits
  add column if not exists user_id uuid references auth.users,
  add column if not exists balance int default 0 not null;

-- Add index for webhook lookups
create index if not exists idx_user_credits_user_id
  on public.user_credits(user_id);

-- Allow service role to upsert credits (for webhook)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'user_credits'
    and policyname = 'Service role can upsert credits'
  ) then
    execute 'create policy "Service role can upsert credits"
      on public.user_credits for all
      using (true)
      with check (true)';
  end if;
end $$;

-- Function to add credits atomically (used by webhook)
-- Uses user_id as the lookup key; inserts row if not exists
create or replace function add_credits(p_user_id uuid, p_amount int)
returns void
language plpgsql
security definer
as $$
begin
  -- Try update first
  update public.user_credits
    set balance = balance + p_amount
  where user_id = p_user_id;

  -- If no row existed, insert one
  if not found then
    insert into public.user_credits (user_id, balance)
    values (p_user_id, p_amount)
    on conflict (user_id) do update
      set balance = public.user_credits.balance + p_amount;
  end if;
end;
$$;

-- Grant execute to service role
grant execute on function add_credits(uuid, int) to service_role;
