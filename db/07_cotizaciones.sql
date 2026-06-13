-- =============================================================
-- BLOQUE 7: Cotizaciones de proyectos IT
-- Pegar en SQL Editor y correr
-- =============================================================

-- Cotizaciones: una por proyecto, con versionado
create table if not exists cotizaciones (
  id bigserial primary key,
  proyecto_id bigint not null references proyectos(id) on delete cascade,
  version int not null default 1,
  titulo text not null,
  estado text not null default 'borrador'
    check (estado in ('borrador','enviada','aprobada','rechazada','vencida')),
  moneda text not null default 'USD' check (moneda in ('USD','ARS')),
  tipo_cambio numeric(14,4) default 1,  -- si ARS, valor del USD; si USD, 1
  vigencia_dias int default 15,           -- dias de validez
  fecha date not null default current_date,
  notas text,
  descuento_pct numeric(5,2) default 0,
  iva_pct numeric(5,2) default 21,
  total numeric(14,2) default 0,         -- denormalizado, recalculado al guardar
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_cot_proy on cotizaciones(proyecto_id);
alter table cotizaciones enable row level security;
drop policy if exists "sp_cot_read" on cotizaciones;
create policy "sp_cot_read" on cotizaciones
  for select to authenticated
  using (public.has_role(array['admin','gerencia','proyectos','ventas']));
drop policy if exists "sp_cot_write" on cotizaciones;
create policy "sp_cot_write" on cotizaciones
  for all to authenticated
  using (public.has_role(array['admin','proyectos','ventas']))
  with check (public.has_role(array['admin','proyectos','ventas']));

-- Items: tipo define color y comportamiento
create table if not exists cotizacion_items (
  id bigserial primary key,
  cotizacion_id bigint not null references cotizaciones(id) on delete cascade,
  tipo text not null check (tipo in ('material','equipo','mano_obra','servicio')),
  orden int not null default 0,
  cantidad numeric(12,2) not null default 1,
  unidad text default 'unidad',          -- mts, un, boca, camara, etc
  descripcion text not null,
  precio_unitario numeric(14,2) not null default 0,
  subtotal numeric(14,2) not null default 0,  -- denormalizado
  notas text
);
create index if not exists idx_cotitems_cot on cotizacion_items(cotizacion_id);
alter table cotizacion_items enable row level security;
drop policy if exists "sp_cotitems_read" on cotizacion_items;
create policy "sp_cotitems_read" on cotizacion_items
  for select to authenticated
  using (public.has_role(array['admin','gerencia','proyectos','ventas']));
drop policy if exists "sp_cotitems_write" on cotizacion_items;
create policy "sp_cotitems_write" on cotizacion_items
  for all to authenticated
  using (public.has_role(array['admin','proyectos','ventas']))
  with check (public.has_role(array['admin','proyectos','ventas']));

-- Catalogo maestro de items frecuentes (opcional, autocompletar)
create table if not exists cotizacion_catalogo (
  id bigserial primary key,
  tipo text not null check (tipo in ('material','equipo','mano_obra','servicio')),
  descripcion text not null,
  unidad text default 'unidad',
  precio_referencial numeric(14,2),
  categoria text,
  created_at timestamptz not null default now()
);
alter table cotizacion_catalogo enable row level security;
drop policy if exists "sp_cotcat_read" on cotizacion_catalogo;
create policy "sp_cotcat_read" on cotizacion_catalogo
  for select to authenticated using (true);
drop policy if exists "sp_cotcat_write" on cotizacion_catalogo;
create policy "sp_cotcat_write" on cotizacion_catalogo
  for all to authenticated
  using (public.has_role(array['admin','proyectos','compras']))
  with check (public.has_role(array['admin','proyectos','compras']));

-- Triggers updated_at
drop trigger if exists tg_cotizaciones_updated on cotizaciones;
create trigger tg_cotizaciones_updated before update on cotizaciones
  for each row execute function tg_touch_updated_at();

-- Datos semilla del catalogo (basado en tu Excel)
insert into cotizacion_catalogo (tipo, descripcion, unidad, precio_referencial, categoria) values
  ('material','P.CORD CAT.6 3,0 MT NEGRO','un',12.89,'Cables'),
  ('material','P.CORD CAT.6 0,6 MT NEGRO','un',10.00,'Cables'),
  ('material','JACK RJ45 CAT.6 NEGRO (SL)','un',8.65,'Conectores'),
  ('material','ORGANIZADOR 2U CON TAPA','un',12.00,'Rack'),
  ('material','PATCH PANEL CAT.6 48 PORTS','un',150.13,'Rack'),
  ('material','Roseta RJ-45 2 puertos - Blanco - Commscope','un',5.00,'Conectores'),
  ('material','CABLE CAT. 6 - AZUL (x 305 mts) 24AWG','mts',1.03,'Cables'),
  ('equipo','NVR HIKVISION 128 canales','un',13000,'Seguridad'),
  ('equipo','Camaras IP 4mpx Hikvision','un',250,'Seguridad'),
  ('equipo','Arcos de seguridad garrett 6500i','un',8000,'Seguridad'),
  ('equipo','HDD 4 teras','un',180,'Storage'),
  ('equipo','Switch 24 poe bocas + Lic.','un',5500,'Redes'),
  ('equipo','Switch 48 poe bocas + Lic.','un',9530,'Redes'),
  ('equipo','1000BASE-SX SFP transceiver module, MMF, 850nm, DOM','un',2200,'Redes'),
  ('mano_obra','Mano de obra SIN BANDEJA','boca',110,'Instalacion')
on conflict do nothing;

select 'Schema de cotizaciones listo.' as status;
