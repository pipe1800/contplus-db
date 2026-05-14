-- =============================================================================
-- ContPlus 6 → PostgreSQL Migration
-- Original: Visual FoxPro 9.0 + Microsoft SQL Server
-- Target: Supabase PostgreSQL
-- =============================================================================

-- =============================================================================
-- EXTENSIONS
-- =============================================================================
create extension if not exists "uuid-ossp";

-- =============================================================================
-- AUTH INTEGRATION: Link Supabase auth.users to our Usuario table
-- =============================================================================
create table if not exists public.usuario_profile (
  id serial primary key,
  user_id uuid references auth.users(id) on delete cascade unique not null,
  created_at timestamp with time zone default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.usuario_profile (user_id) values (new.id);
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================================
-- CORE: Company & Fiscal Periods
-- =============================================================================

-- Company configuration
create table cia (
  id serial primary key,
  nombre varchar(150),
  cuentas char(9),
  mayor smallint,
  firma1col1 varchar(30),
  firma1col2 varchar(30),
  firma1col3 varchar(30),
  firma2col1 varchar(30),
  firma2col2 varchar(30),
  firma2col3 varchar(30),
  psw_mes varchar(15),
  psw_year varchar(15),
  last_one boolean default true,
  capital varchar(25) default 'CAPITAL',
  perdida varchar(30) default 'DEFICIT DEL EJERCICIO',
  ganancia varchar(30) default 'SUPERAVIT DEL EJERCICIO',
  resultado varchar(30) default 'RESULTADO DEL EJERCICIO',
  print_cero boolean default false,
  egresos_bs varchar(30) default 'ACTIVOS, COSTOS Y GASTOS',
  ingresos_bs varchar(30) default 'PASIVO, CAPITAL Y PRODUCTOS',
  egresos_bc varchar(30) default 'ACTIVOS, COSTOS Y GASTOS',
  ingresos_bc varchar(30) default 'PASIVO, CAPITAL E INGRESOS',
  id_cia char(15),
  transito varchar(21) default '',
  plantilla int default 0
);
create index idx_cia_id_cia on cia(id_cia);

-- Fiscal periods (one per month)
create table fecha_s (
  fecha timestamp not null,
  cia int not null,
  partida int default 0,
  voucher int default 0,
  primary key (cia, fecha)
);

-- =============================================================================
-- CORE: Chart of Accounts
-- =============================================================================

create table catalogo (
  cuenta char(21) not null,
  nombre varchar(40) default '',
  tipo char(1),
  cuentd varchar(21) default '0',
  nivel smallint,
  fecha_ini timestamp not null,
  cia int not null,
  primary key (cia, cuenta, fecha_ini)
);
create index idx_catalogo_nombre on catalogo(cia, nombre, fecha_ini);

-- Tracks which accounts have sub-accounts (closed/inactive parents)
create table fecha_fin (
  cuenta char(21) not null,
  fecha_ini timestamp not null,
  fin timestamp not null,
  cia int not null,
  cta_hija char(21),
  primary key (cia, cuenta, fecha_ini)
);

-- =============================================================================
-- CORE: Banks & Checks
-- =============================================================================

create table bancos (
  id serial,
  cuenta char(21) not null,
  nombre varchar(50),
  no_cta varchar(20),
  ciudad varchar(18),
  banco varchar(20),
  serie varchar(8),
  no_cheque int,
  cia int not null,
  n_year smallint not null,
  primary key (cia, cuenta, n_year)
);

create table cheque_h (
  voucher int not null,
  fecha_vou timestamp not null,
  no_cheque int not null,
  fecha_cheq timestamp not null,
  serie varchar(8),
  valor decimal(12,2),
  cuenta char(21),
  nombre varchar(60),
  anulado boolean default false,
  mes timestamp not null,
  fecha_sys timestamp default now(),
  cia int not null,
  id_cheque int not null,
  cargo decimal(18,2),
  abono decimal(18,2),
  primary key (cia, mes, voucher, no_cheque, fecha_vou)
);

create table cheque_d (
  voucher int not null,
  fecha_mov timestamp not null,
  cuenta char(21) not null,
  concepto varchar(100),
  cargo decimal(18,2),
  abono decimal(18,2),
  mes timestamp not null,
  item smallint not null,
  cia int not null,
  id_cheq int not null,
  formula varchar(100),
  primary key (cia, mes, voucher, item, id_cheq)
);

create table trabajo (
  cuenta char(21) not null,
  id_pc int
);

-- =============================================================================
-- CORE: Balances
-- =============================================================================

create table saldo_dia (
  cia int not null,
  fecha timestamp not null,
  cuenta char(21) not null,
  saldo decimal(18,2),
  primary key (cia, cuenta, fecha)
);

create table saldo_ant (
  cuenta char(21) not null,
  saldo decimal(18,2) default 0.00,
  anio smallint not null,
  cia int not null,
  primary key (cia, anio, cuenta)
);

create table saldos (
  cuenta char(21) not null,
  cargo decimal(18,2) default 0.00,
  abono decimal(18,2) default 0.00,
  sald_mes decimal(18,2) default 0.00,
  fecha timestamp not null,
  cia int not null,
  primary key (cia, cuenta, fecha)
);

create table estado_r (
  cuenta char(21) not null,
  sald_mes decimal(18,2) default 0.00,
  fecha timestamp not null,
  cia int not null,
  primary key (cia, cuenta, fecha)
);

-- =============================================================================
-- CORE: Journal Entries (Diario) & Concepts
-- =============================================================================

create table diario (
  numero int not null,
  ext char(1) not null,
  fecha_mov timestamp not null,
  cuenta char(21) not null,
  concepto varchar(100),
  cargo decimal(18,2),
  abono decimal(18,2),
  mes timestamp not null,
  item smallint not null,
  cia int not null,
  id_partida int not null,
  formula varchar(100),
  primary key (cia, mes, numero, ext, item, id_partida)
);

create table concepto (
  numero int not null,
  ext char(1) not null,
  linea varchar(100),
  fecha_pda timestamp not null,
  cargo decimal(18,2) default 0.00,
  abono decimal(18,2) default 0.00,
  mes timestamp not null,
  fecha_sys timestamp default now(),
  cia int not null,
  id_pda int not null,
  tipo_pda smallint default 0,
  primary key (cia, mes, numero, ext, id_pda)
);

-- =============================================================================
-- CORE: Journal Templates
-- =============================================================================

create table plantilla_h (
  cia int not null,
  id_pda int not null,
  linea varchar(100),
  nombre varchar(50),
  primary key (cia, id_pda)
);

create table plantilla_d (
  cuenta char(21) not null,
  concepto varchar(100),
  cargo decimal(18,2),
  abono decimal(18,2),
  cia int not null,
  id_partida int not null,
  item smallint not null,
  formula varchar(100),
  primary key (cia, id_partida, item)
);

-- =============================================================================
-- CORE: Report Formatting
-- =============================================================================

create table impress (
  id serial,
  lin decimal(6,2),
  col smallint,
  dato_print varchar(20) default ' ',
  _exec varchar(90) default ' ',
  pic varchar(20) default ' ',
  font varchar(15) default ' ',
  size decimal(6,2),
  style varchar(3),
  grove varchar(8),
  imp_with_0 boolean default false,
  cuenta char(21) not null,
  cia int not null,
  primary key (cia, cuenta)
);
create index idx_impress_id on impress(id);

-- =============================================================================
-- CORE: Update Management
-- =============================================================================

create table actualizar (
  c_version char(12),
  c_exe bytea,
  c_sys_upd bytea,
  c_load bytea,
  item serial
);
insert into actualizar (c_version) values ('90720130903');

-- =============================================================================
-- AUTH: Users & Permissions
-- =============================================================================

create table usuario (
  id serial,
  nombre varchar(15) not null,
  intentos_def smallint default 0,
  intentos_act smallint default 0,
  ult_acceso timestamp,
  psw char(12),
  bloqueado boolean default false,
  sistema boolean default false,
  primary key (nombre)
);
-- Default admin account
insert into usuario (nombre, psw, intentos_def, sistema) values ('Admin', '123456', 3, true);

-- =============================================================================
-- SYSTEM: Menu Structure
-- =============================================================================

create table pad_menu (
  id serial,
  nombre varchar(50),
  primary key (id)
);

create table section_menu (
  id serial,
  nombre varchar(90),
  primary key (id)
);

create table app_menu (
  id serial,
  titulo varchar(50),
  pict char(3) default '   ',
  tip_text varchar(90),
  _exec varchar(30),
  _param varchar(5),
  attrib char(5),
  icono bytea,
  skip_for varchar(90),
  admin boolean default false,
  primary key (id)
);

create table option_menu (
  id_user smallint not null,
  id_app smallint not null,
  id_pad smallint not null,
  id_sec smallint not null,
  num_item smallint,
  attrib char(5),
  primary key (id_user, id_app, id_pad, id_sec)
);

create table reporte (
  id serial,
  nombre varchar(60),
  titulo varchar(60),
  c_rpte bytea,
  original int default 0,
  version int default 0,
  primary key (id)
);

-- =============================================================================
-- IVA MODULE: Tax Configuration
-- =============================================================================

create table i_cia (
  id int not null,
  nrc varchar(10) not null,
  nit varchar(17),
  giro varchar(60),
  gran_contrb boolean,
  primary key (id)
);

create table i_fechas (
  fecha timestamp,
  cia int not null,
  last_one boolean default true
);
create unique index idx_i_fechas_active on i_fechas(cia) where last_one = true;

-- =============================================================================
-- IVA MODULE: Branches, Cash Registers, Document Types
-- =============================================================================

create table i_sucursal (
  id serial,
  nombre varchar(40) not null,
  direccion varchar(60),
  cia int not null,
  primary key (id)
);

create table i_caja (
  cia int not null,
  suc smallint not null,
  no_caja smallint not null,
  no_maq_reg varchar(10),
  primary key (cia, suc, no_caja)
);

create table i_tipos_doc (
  id serial,
  nombre varchar(30) not null,
  muestra varchar(4) not null,
  porc_iva decimal(6,2) default 0.00,
  porc_ret decimal(6,2) default 0.00,
  monto_act decimal(12,2) default 0.00,
  fa boolean default false,
  signo char(1),
  xportac boolean default false,
  primary key (id)
);
-- Seed IVA document types (El Salvador)
insert into i_tipos_doc (nombre, muestra, porc_iva, porc_ret, monto_act, fa, signo, xportac)
values
  ('Credito Fiscal', 'CF', 13, 1, 12435.99, false, '+', false),
  ('Consumidor Final', 'FA', 13, 0, 0, true, '+', false),
  ('Factura Exportacion', 'FX', 0, 0, 0, true, '+', true),
  ('Tiquete', 'TI', 13, 0, 0, true, '+', false),
  ('Nota de Credito', 'NC', 13, 0, 0, false, '-', false);

-- =============================================================================
-- IVA MODULE: Clients/Providers
-- =============================================================================

create table i_clientes (
  id serial,
  nombre varchar(50) not null,
  nit varchar(17) not null,
  giro varchar(60) not null,
  direccion varchar(70),
  cliprov smallint not null,
  tipo_cli smallint,
  tipo_prov smallint,
  gc_ex_nos smallint,
  nrc varchar(10) not null,
  primary key (id)
);
create index idx_i_clientes_nrc on i_clientes(nrc);
create index idx_i_clientes_nombre on i_clientes(nombre);

-- =============================================================================
-- IVA MODULE: Purchases (Compras)
-- =============================================================================

create table i_compras (
  rec_no serial,
  cia int not null,
  suc smallint not null,
  f_doc timestamp not null,
  tipo_doc smallint not null,
  num_doc int not null,
  provee int not null,
  exento decimal(12,2) default 0.00,
  neto decimal(12,2) default 0.00,
  iva decimal(12,2) default 0.00,
  total decimal(12,2) default 0.00,
  excluido decimal(12,2) default 0.00,
  ret3ros decimal(12,2) default 0.00,
  anulada boolean default false,
  porc_iva decimal(6,2),
  fecha timestamp not null,
  compra boolean not null
);

-- =============================================================================
-- IVA MODULE: Sales - Consumer Final (Ventas CF)
-- =============================================================================

create table i_ventas_cf (
  rec_no serial,
  cia int not null,
  suc smallint not null,
  f_doc timestamp not null,
  tipo_doc smallint not null,
  num_doc int not null,
  cliente int not null,
  exento decimal(12,2) default 0.00,
  neto decimal(12,2) default 0.00,
  iva_vtas decimal(12,2) default 0.00,
  total decimal(12,2) default 0.00,
  anulada boolean default false,
  iva3ro decimal(12,2) default 0.00,
  percep decimal(12,2) default 0.00,
  porc_iva decimal(6,2) default 0.00,
  fecha timestamp not null
);

-- =============================================================================
-- IVA MODULE: Sales - Factura (Ventas FA)
-- =============================================================================

create table i_ventas_fa (
  rec_no serial,
  cia int not null,
  suc smallint not null,
  cliente int not null,
  f_doc timestamp not null,
  no_caja smallint not null,
  tipo_doc smallint not null,
  num_doc int not null,
  num_max int not null,
  decl_export varchar(15),
  exento decimal(12,2) default 0.00,
  neto decimal(12,2) default 0.00,
  ret3ro decimal(12,2) default 0.00,
  total decimal(12,2) default 0.00,
  anulada boolean default false,
  porc_iva decimal(6,2),
  fecha timestamp not null
);

-- =============================================================================
-- ROW-LEVEL SECURITY (RLS)
-- =============================================================================

-- Tables with company scoping (have 'cia' column)
alter table fecha_s enable row level security;
alter table catalogo enable row level security;
alter table fecha_fin enable row level security;
alter table bancos enable row level security;
alter table cheque_h enable row level security;
alter table cheque_d enable row level security;
alter table trabajo enable row level security;
alter table saldo_dia enable row level security;
alter table saldo_ant enable row level security;
alter table saldos enable row level security;
alter table estado_r enable row level security;
alter table diario enable row level security;
alter table concepto enable row level security;
alter table plantilla_h enable row level security;
alter table plantilla_d enable row level security;
alter table impress enable row level security;
alter table i_cia enable row level security;
alter table i_fechas enable row level security;
alter table i_sucursal enable row level security;
alter table i_caja enable row level security;
alter table i_tipos_doc enable row level security;
alter table i_clientes enable row level security;
alter table i_compras enable row level security;
alter table i_ventas_cf enable row level security;
alter table i_ventas_fa enable row level security;

-- For now, simple RLS: authenticated users see all data within their session
-- (Will be refined with proper company_id claims once auth is wired up)
create policy "auth_users_read_fecha_s" on fecha_s for all using (auth.role() = 'authenticated');
create policy "auth_users_read_catalogo" on catalogo for all using (auth.role() = 'authenticated');
create policy "auth_users_read_fecha_fin" on fecha_fin for all using (auth.role() = 'authenticated');
create policy "auth_users_read_bancos" on bancos for all using (auth.role() = 'authenticated');
create policy "auth_users_read_cheque_h" on cheque_h for all using (auth.role() = 'authenticated');
create policy "auth_users_read_cheque_d" on cheque_d for all using (auth.role() = 'authenticated');
create policy "auth_users_read_trabajo" on trabajo for all using (auth.role() = 'authenticated');
create policy "auth_users_read_saldo_dia" on saldo_dia for all using (auth.role() = 'authenticated');
create policy "auth_users_read_saldo_ant" on saldo_ant for all using (auth.role() = 'authenticated');
create policy "auth_users_read_saldos" on saldos for all using (auth.role() = 'authenticated');
create policy "auth_users_read_estado_r" on estado_r for all using (auth.role() = 'authenticated');
create policy "auth_users_read_diario" on diario for all using (auth.role() = 'authenticated');
create policy "auth_users_read_concepto" on concepto for all using (auth.role() = 'authenticated');
create policy "auth_users_read_plantilla_h" on plantilla_h for all using (auth.role() = 'authenticated');
create policy "auth_users_read_plantilla_d" on plantilla_d for all using (auth.role() = 'authenticated');
create policy "auth_users_read_impress" on impress for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_cia" on i_cia for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_fechas" on i_fechas for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_sucursal" on i_sucursal for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_caja" on i_caja for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_tipos_doc" on i_tipos_doc for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_clientes" on i_clientes for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_compras" on i_compras for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_ventas_cf" on i_ventas_cf for all using (auth.role() = 'authenticated');
create policy "auth_users_read_i_ventas_fa" on i_ventas_fa for all using (auth.role() = 'authenticated');

-- Company table: accessible by authenticated users
alter table cia enable row level security;
create policy "auth_users_read_cia" on cia for all using (auth.role() = 'authenticated');

-- Menu/permissions tables accessible by authenticated users
alter table usuario enable row level security;
create policy "auth_users_read_usuario" on usuario for select using (auth.role() = 'authenticated');

alter table pad_menu enable row level security;
create policy "auth_users_read_pad_menu" on pad_menu for select using (auth.role() = 'authenticated');

alter table section_menu enable row level security;
create policy "auth_users_read_section_menu" on section_menu for select using (auth.role() = 'authenticated');

alter table app_menu enable row level security;
create policy "auth_users_read_app_menu" on app_menu for select using (auth.role() = 'authenticated');

alter table option_menu enable row level security;
create policy "auth_users_read_option_menu" on option_menu for select using (auth.role() = 'authenticated');

alter table reporte enable row level security;
create policy "auth_users_read_reporte" on reporte for select using (auth.role() = 'authenticated');

alter table actualizar enable row level security;
create policy "auth_users_read_actualizar" on actualizar for select using (auth.role() = 'authenticated');

-- =============================================================================
-- FUNCTIONS: Core Accounting Logic
-- =============================================================================

-- Get account balance at a given date
create or replace function f_get_saldo(
  p_cia int,
  p_fecha timestamp,
  p_cuenta char(21),
  p_tipo int default 1
) returns decimal(18,2)
language plpgsql
as $$
declare
  v_saldo decimal(18,2);
begin
  select sald_mes into v_saldo from saldos
  where cia = p_cia and fecha = p_fecha and cuenta = p_cuenta;
  return coalesce(v_saldo, 0.00);
end;
$$;

-- Order accounts for display (replaces f_OrdenCta)
create or replace function f_orden_cta(cuenta char(21)) returns char(22)
language sql
immutable
as $$
  select
    case
      when right(rtrim(cuenta), 1) = 'R'
      then left(rtrim(cuenta), length(rtrim(cuenta)) - 1) || 'R'
      else rtrim(cuenta) || ' '
    end;
$$;

-- Get dependent parent account
create or replace function get_cuentd(
  p_cia int,
  p_mes timestamp,
  p_cuenta char(21)
) returns char(21)
language plpgsql
as $$
declare
  v_limpia varchar(21);
  v_pos char(1);
  v_len int;
  v_cta_tmp char(21);
begin
  v_limpia := rtrim(p_cuenta);
  v_pos := right(v_limpia, 1);
  if v_pos = 'R' then
    v_limpia := left(v_limpia, length(v_limpia) - 1);
  else
    v_pos := '';
  end if;
  v_len := length(v_limpia);

  while v_len > 2 loop
    v_len := v_len - 1;
    v_cta_tmp := null;
    if v_pos = 'R' then
      select cuenta into v_cta_tmp from catalogo
      where cia = p_cia and extract(year from fecha_ini) = extract(year from p_mes)
      and cuenta = left(v_limpia, v_len) || v_pos;
    end if;
    if v_cta_tmp is null then
      select cuenta into v_cta_tmp from catalogo
      where cia = p_cia and extract(year from fecha_ini) = extract(year from p_mes)
      and cuenta = left(v_limpia, v_len);
    end if;
    if v_cta_tmp is not null then
      return v_cta_tmp;
    end if;
  end loop;
  return '0';
end;
$$;

-- Post journal entries to ledger (replaces sp_MayorizarCta)
create or replace function mayorizar_cta(
  p_cia int,
  p_fecha timestamp,
  p_cta char(21)
) returns void
language plpgsql
as $$
declare
  v_cuenta char(21);
  v_cargo_d decimal(18,2);
  v_abono_d decimal(18,2);
  v_cargo_v decimal(18,2);
  v_abono_v decimal(18,2);
  v_tipo char(1);
begin
  v_cuenta := p_cta;

  -- Sum from journal entries
  select coalesce(sum(cargo), 0), coalesce(sum(abono), 0)
  into v_cargo_d, v_abono_d
  from diario where cia = p_cia and mes = p_fecha and cuenta = p_cta;

  -- Sum from checks (non-voided)
  select coalesce(sum(a.cargo), 0), coalesce(sum(a.abono), 0)
  into v_cargo_v, v_abono_v
  from cheque_d a
  left join cheque_h b on a.cia = b.cia and a.mes = b.mes and a.id_cheq = b.id_cheque
  where a.cia = p_cia and a.mes = p_fecha and a.cuenta = p_cta and b.anulado = false;

  -- Walk up the account hierarchy
  while v_cuenta <> '0' loop
    select tipo into v_tipo from catalogo
    where cia = p_cia and extract(year from fecha_ini) = extract(year from p_fecha)
    and cuenta = v_cuenta;

    -- Upsert balance
    insert into saldos (cuenta, cargo, abono, sald_mes, fecha, cia)
    values (v_cuenta, v_cargo_d + v_cargo_v, v_abono_d + v_abono_v, 0, p_fecha, p_cia)
    on conflict (cia, cuenta, fecha) do update
    set cargo = saldos.cargo + v_cargo_d + v_cargo_v,
        abono = saldos.abono + v_abono_d + v_abono_v;

    -- Update running balance based on account type
    if v_tipo in ('A','E','R','O') then
      update saldos set sald_mes = cargo - abono
      where cia = p_cia and fecha = p_fecha and cuenta = v_cuenta;
    else
      update saldos set sald_mes = abono - cargo
      where cia = p_cia and fecha = p_fecha and cuenta = v_cuenta;
    end if;

    -- Move to parent account
    select cuentd, tipo into v_cuenta, v_tipo from catalogo
    where cia = p_cia and extract(year from fecha_ini) = extract(year from p_fecha)
    and cuenta = v_cuenta;
  end loop;
end;
$$;

-- Initialize balances for a period
create or replace function inicializa_saldos(
  p_cia int,
  p_fecha timestamp
) returns void
language sql
as $$
  update saldos set cargo = 0, abono = 0, sald_mes = 0
  where cia = p_cia and fecha = p_fecha;
$$;

-- Calculate income statement result
create or replace function calc_resultado(
  p_cia int,
  p_mes timestamp
) returns decimal(18,2)
language plpgsql
as $$
declare
  v_result decimal(18,2);
begin
  select coalesce(sum(
    case when b.tipo in ('A','E','R','O') then a.sald_mes else -a.sald_mes end
  ), 0) into v_result
  from saldos a
  join catalogo b on a.cia = b.cia
    and extract(year from b.fecha_ini) = extract(year from p_mes)
    and a.cuenta = b.cuenta
  where a.cia = p_cia and a.fecha = p_mes
    and b.tipo in ('E','I','R','O')
    and b.nivel > 0;

  return v_result;
end;
$$;

-- Save income statement snapshot
create or replace function save_estado_r(
  p_cia int,
  p_fecha timestamp
) returns void
language sql
as $$
  delete from estado_r where cia = p_cia and fecha = p_fecha;
  insert into estado_r (cuenta, sald_mes, fecha, cia)
  select a.cuenta, a.sald_mes, a.fecha, a.cia
  from saldos a
  join catalogo b on a.cia = b.cia
    and extract(year from b.fecha_ini) = extract(year from a.fecha)
    and a.cuenta = b.cuenta
  where a.cia = p_cia and a.fecha = p_fecha
    and b.tipo in ('E','I')
    and b.nivel > 0;
$$;

-- Initialize IVA fiscal period
create or replace function i_add_fecha(
  p_cia int,
  p_fecha timestamp
) returns void
language sql
as $$
  update i_fechas set last_one = false where last_one = true and cia = p_cia;
  insert into i_fechas (cia, fecha) values (p_cia, p_fecha);
$$;
