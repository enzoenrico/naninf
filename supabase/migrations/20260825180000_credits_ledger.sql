-- Credits ledger for NanInf (server-authoritative).
-- Apply with: supabase db push   (or SQL editor in dashboard)

create table if not exists public.credit_balances (
  user_id uuid primary key references auth.users (id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  starter_granted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  amount integer not null,
  idempotency_key text not null,
  generation_id text,
  hold_id uuid,
  revenuecat_event_id text,
  product_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint credit_ledger_idempotency_key_key unique (idempotency_key)
);

create unique index if not exists credit_ledger_revenuecat_event_id_uidx
  on public.credit_ledger (revenuecat_event_id)
  where revenuecat_event_id is not null;

create table if not exists public.credit_holds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  generation_id text not null,
  spend text not null,
  cost integer not null check (cost > 0),
  status text not null default 'held' check (status in ('held', 'captured', 'released')),
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index if not exists credit_holds_user_status_idx on public.credit_holds (user_id, status);

alter table public.credit_balances enable row level security;
alter table public.credit_ledger enable row level security;
alter table public.credit_holds enable row level security;

-- Clients read their own balance via Data API if needed; mutations go through Edge Functions (service role).
drop policy if exists credit_balances_select_own on public.credit_balances;
create policy credit_balances_select_own
  on public.credit_balances
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists credit_ledger_select_own on public.credit_ledger;
create policy credit_ledger_select_own
  on public.credit_ledger
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists credit_holds_select_own on public.credit_holds;
create policy credit_holds_select_own
  on public.credit_holds
  for select
  to authenticated
  using (auth.uid() = user_id);
