-- =============================================================================
-- Migration: Foreign Keys + Multi-Tenant Workspace + RLS Overhaul
-- =============================================================================

-- Pre-step: Fix imported company IDs (SQL Server had id=20, Postgres serial = 1)
update fecha_s set cia = 1 where cia = 20;
update catalogo set cia = 1 where cia = 20;
update fecha_fin set cia = 1 where cia = 20;
update bancos set cia = 1 where cia = 20;
update cheque_h set cia = 1 where cia = 20;
update cheque_d set cia = 1 where cia = 20;
update trabajo set cia = 1 where cia = 20;
update saldo_dia set cia = 1 where cia = 20;
update saldo_ant set cia = 1 where cia = 20;
update saldos set cia = 1 where cia = 20;
update estado_r set cia = 1 where cia = 20;
update diario set cia = 1 where cia = 20;
update concepto set cia = 1 where cia = 20;
update plantilla_h set cia = 1 where cia = 20;
update plantilla_d set cia = 1 where cia = 20;
update impress set cia = 1 where cia = 20;
update i_fechas set cia = 1 where cia = 20;
update i_sucursal set cia = 1 where cia = 20;
update i_caja set cia = 1 where cia = 20;
update i_compras set cia = 1 where cia = 20;
update i_ventas_cf set cia = 1 where cia = 20;
update i_ventas_fa set cia = 1 where cia = 20;
-- Reset company serial to avoid future conflicts (now id=1, not 20)
alter sequence cia_id_seq restart with 2;

-- =============================================================================
-- 1. COMPANY MEMBERSHIP TABLE (multi-user workspace support)
-- =============================================================================

create table if not exists company_members (
  id serial primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  company_id int references cia(id) on delete cascade not null,
  role varchar(20) default 'accountant' check (role in ('owner', 'accountant', 'viewer')),
  created_at timestamp with time zone default now(),
  unique (user_id, company_id)
);
create index idx_company_members_user on company_members(user_id);
create index idx_company_members_company on company_members(company_id);

-- Helper function: get companies the current user belongs to
create or replace function public.user_company_ids()
returns setof int
language sql
stable
security definer
as $$
  select company_id from company_members where user_id = auth.uid();
$$;

-- =============================================================================
-- 2. FOREIGN KEY CONSTRAINTS
-- =============================================================================

-- Core accounting FKs (idempotent)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_fecha_s_cia') then
    alter table fecha_s add constraint fk_fecha_s_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_catalogo_cia') then
    alter table catalogo add constraint fk_catalogo_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_fecha_fin_cia') then
    alter table fecha_fin add constraint fk_fecha_fin_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_bancos_cia') then
    alter table bancos add constraint fk_bancos_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_cheque_h_cia') then
    alter table cheque_h add constraint fk_cheque_h_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_cheque_d_cia') then
    alter table cheque_d add constraint fk_cheque_d_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_trabajo_cia') then
    alter table trabajo add constraint fk_trabajo_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_saldo_dia_cia') then
    alter table saldo_dia add constraint fk_saldo_dia_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_saldo_ant_cia') then
    alter table saldo_ant add constraint fk_saldo_ant_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_saldos_cia') then
    alter table saldos add constraint fk_saldos_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_estado_r_cia') then
    alter table estado_r add constraint fk_estado_r_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_diario_cia') then
    alter table diario add constraint fk_diario_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_concepto_cia') then
    alter table concepto add constraint fk_concepto_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_plantilla_h_cia') then
    alter table plantilla_h add constraint fk_plantilla_h_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_plantilla_d_cia') then
    alter table plantilla_d add constraint fk_plantilla_d_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_impress_cia') then
    alter table impress add constraint fk_impress_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_cia_cia') then
    alter table i_cia add constraint fk_i_cia_cia foreign key (id) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_fechas_cia') then
    alter table i_fechas add constraint fk_i_fechas_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_sucursal_cia') then
    alter table i_sucursal add constraint fk_i_sucursal_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_caja_cia') then
    alter table i_caja add constraint fk_i_caja_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_compras_cia') then
    alter table i_compras add constraint fk_i_compras_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_ventas_cf_cia') then
    alter table i_ventas_cf add constraint fk_i_ventas_cf_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_i_ventas_fa_cia') then
    alter table i_ventas_fa add constraint fk_i_ventas_fa_cia foreign key (cia) references cia(id) on delete cascade;
  end if;
end;
$$;

-- =============================================================================
-- 3. RLS OVERHAUL — Drop old policies, create company-scoped ones
-- =============================================================================

-- Helper: drop all existing policies safely
do $$
declare
  pol record;
begin
  for pol in
    select policyname, tablename from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on %I', pol.policyname, pol.tablename);
  end loop;
end;
$$;

-- Company-scoped tables (have 'cia' column): authenticated users see their companies
do $$
declare
  t text;
begin
  for t in
    select unnest(array[
      'cia', 'fecha_s', 'catalogo', 'fecha_fin', 'bancos',
      'cheque_h', 'cheque_d', 'trabajo', 'saldo_dia', 'saldo_ant',
      'saldos', 'estado_r', 'diario', 'concepto', 'plantilla_h',
      'plantilla_d', 'impress',
      'i_cia', 'i_fechas', 'i_sucursal', 'i_caja',
      'i_compras', 'i_ventas_cf', 'i_ventas_fa'
    ])
  loop
    -- The table 'cia' uses 'id' for company, not 'cia' column
    -- All other tables use 'cia' column
    execute format('
      create policy "company_scoped" on %I
        for all
        using (%s in (select public.user_company_ids()))
        with check (%s in (select public.user_company_ids()))
    ', t,
      case when t = 'cia' then 'id' else 'cia' end,
      case when t = 'cia' then 'id' else 'cia' end
    );
  end loop;
end;
$$;

-- Global lookup tables: readable by all authenticated, writable by owners
alter table i_tipos_doc enable row level security;
create policy "read_all" on i_tipos_doc for select using (auth.role() = 'authenticated');

alter table i_clientes enable row level security;
create policy "read_all" on i_clientes for select using (auth.role() = 'authenticated');

-- Membership table: users can only see their own memberships
alter table company_members enable row level security;
create policy "own_memberships" on company_members
  for select using (user_id = auth.uid());

-- System tables: authenticated users can read
alter table usuario enable row level security;
create policy "auth_read" on usuario for select using (auth.role() = 'authenticated');

alter table pad_menu enable row level security;
create policy "auth_read" on pad_menu for select using (auth.role() = 'authenticated');

alter table section_menu enable row level security;
create policy "auth_read" on section_menu for select using (auth.role() = 'authenticated');

alter table app_menu enable row level security;
create policy "auth_read" on app_menu for select using (auth.role() = 'authenticated');

alter table option_menu enable row level security;
create policy "auth_read" on option_menu for select using (auth.role() = 'authenticated');

alter table reporte enable row level security;
create policy "auth_read" on reporte for select using (auth.role() = 'authenticated');

alter table actualizar enable row level security;
create policy "auth_read" on actualizar for select using (auth.role() = 'authenticated');

-- =============================================================================
-- 4. SEED: Add the imported company as owned by the default admin
-- =============================================================================

-- Insert membership for the existing company (cia id=1)
-- This will fail silently if admin user doesn't exist yet; run manually after first signup
-- insert into company_members (user_id, company_id, role)
-- select id, 1, 'owner' from usuario where nombre = 'Admin' limit 1;
