-- =============================================================
-- BLOQUE 21: Portal del Cliente mejorado
-- Archivos, comentarios en linea y firma digital
-- =============================================================

-- Archivos adjuntos (vinculados a una cotizacion o proyecto)
create table if not exists portal_archivos (
  id bigserial primary key,
  portal_id bigint not null references portal_access(id) on delete cascade,
  cotizacion_id bigint references cotizaciones(id) on delete cascade,
  proyecto_id bigint references proyectos(id) on delete cascade,
  nombre text not null,
  descripcion text,
  url_storage text not null,  -- ruta en Storage
  url_publica text not null,
  mime_type text,
  tamano_bytes bigint,
  subido_por text,            -- nombre o email
  subido_por_usuario boolean default false,  -- true si lo subio el admin, false si lo subio el cliente
  created_at timestamptz not null default now()
);
create index if not exists idx_portalarch_portal on portal_archivos(portal_id);
create index if not exists idx_portalarch_cot on portal_archivos(cotizacion_id);

alter table portal_archivos enable row level security;
drop policy if exists "sp_pa_read" on portal_archivos;
create policy "sp_pa_read" on portal_archivos
  for select to anon, authenticated using (true);
drop policy if exists "sp_pa_insert" on portal_archivos;
create policy "sp_pa_insert" on portal_archivos
  for insert to anon, authenticated with check (true);
drop policy if exists "sp_pa_delete" on portal_archivos;
create policy "sp_pa_delete" on portal_archivos
  for delete to anon, authenticated using (true);

-- Comentarios en linea sobre un item especifico
create table if not exists portal_item_comentarios (
  id bigserial primary key,
  portal_id bigint not null references portal_access(id) on delete cascade,
  cotizacion_id bigint not null references cotizaciones(id) on delete cascade,
  item_id bigint not null references cotizacion_items(id) on delete cascade,
  autor_nombre text not null,
  autor_email text,
  texto text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_picom_item on portal_item_comentarios(item_id);
alter table portal_item_comentarios enable row level security;
drop policy if exists "sp_picom_read" on portal_item_comentarios;
create policy "sp_picom_read" on portal_item_comentarios
  for select to anon, authenticated using (true);
drop policy if exists "sp_picom_insert" on portal_item_comentarios;
create policy "sp_picom_insert" on portal_item_comentarios
  for insert to anon, authenticated with check (true);

-- Firmas digitales: registrar aceptacion formal
create table if not exists portal_firmas (
  id bigserial primary key,
  portal_id bigint not null references portal_access(id) on delete cascade,
  cotizacion_id bigint not null references cotizaciones(id) on delete cascade,
  decision text not null check (decision in ('aprobada','rechazada')),
  firmado_por text not null,    -- nombre completo
  email_firmante text,
  cargo text,                    -- opcional (ej: "Director de IT")
  dni_cuit text,                 -- opcional
  ip_address text,
  user_agent text,
  timestamp_firma timestamptz not null default now()
);
alter table portal_firmas enable row level security;
drop policy if exists "sp_pfirma_read" on portal_firmas;
create policy "sp_pfirma_read" on portal_firmas
  for select to anon, authenticated using (true);
drop policy if exists "sp_pfirma_insert" on portal_firmas;
create policy "sp_pfirma_insert" on portal_firmas
  for insert to anon, authenticated with check (true);

-- Bucket para archivos del portal
-- (crear manualmente: Storage -> New bucket -> 'portal-archivos' -> Public)
-- (las politicas RLS se aplican via las tablas portal_archivos, no storage)

select 'Portal mejorado: archivos, comentarios en linea y firma digital listos' as status;
