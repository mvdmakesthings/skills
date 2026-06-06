-- Mark is_admin() STABLE so the planner evaluates it ONCE per statement instead
-- of once per scanned row.
--
-- ROOT CAUSE of the "slow brand_responses query":
-- The brand_responses RLS policy is
--   USING ((account_id = ANY (current_user_account_ids())) OR is_admin())
-- and is_admin() was declared VOLATILE (the SQL default — no volatility keyword
-- in migration 20260531000000_harden_is_admin_search_path.sql). A VOLATILE
-- function in a row filter cannot be hoisted, so Postgres re-runs
-- `select exists(select 1 from public.admins where user_id = auth.uid())`
-- once for EVERY row the scan touches. Cost grows linearly with rows scanned;
-- a 10k-row scan measured ~63-71 ms (and ~10,200 admins-table buffer hits) vs
-- ~1 ms when the same logic is STABLE (planner collapses it to a One-Time
-- Filter). current_user_account_ids() in the same policy is already STABLE.
--
-- The function is a read-only SELECT whose result is constant within a single
-- statement (auth.uid() and admins membership do not change mid-statement), so
-- STABLE is the correct, conservative marking. VOLATILE was an unintended
-- default, not a deliberate choice.
--
-- `create or replace` preserves existing EXECUTE grants (authenticated, anon)
-- and the search_path hardening from 20260531000000 (pg_temp pinned LAST,
-- public.admins schema-qualified) — the ONLY change is adding STABLE.
--
-- NOTE: provided as a proposal artifact. It was NOT applied to any database and
-- was NOT committed to the charter repo, per the run constraints.
--
-- Manual rollback: re-create is_admin() WITHOUT the `stable` keyword (back to
-- the VOLATILE default), keeping the same body and search_path.

create or replace function is_admin() returns boolean
  language sql
  stable
  security definer
  set search_path = public, auth, pg_temp
as $$
  select exists(select 1 from public.admins where user_id = auth.uid())
$$;

comment on function is_admin() is
  'Canonical admin membership probe. SECURITY DEFINER, STABLE (so RLS row filters evaluate it once per statement, not per row). search_path pins pg_temp LAST and the admins reference is schema-qualified (public.admins) so a caller-created temp table cannot shadow the gate (hardened 20260531000000; marked STABLE for RLS planner hoisting).';
