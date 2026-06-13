-- =============================================================
-- BLOQUE 20: Plantillas de cotización
-- =============================================================

create table if not exists cotizacion_plantillas (
  id bigserial primary key,
  nombre text not null,
  descripcion text,
  categoria text,
  icono text default '📋',
  items jsonb not null default '[]',  -- [{tipo, cantidad, unidad, descripcion, precio_unitario}]
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
alter table cotizacion_plantillas enable row level security;
drop policy if exists "sp_plt_read" on cotizacion_plantillas;
create policy "sp_plt_read" on cotizacion_plantillas
  for select to authenticated using (true);
drop policy if exists "sp_plt_write" on cotizacion_plantillas;
create policy "sp_plt_write" on cotizacion_plantillas
  for all to authenticated
  using (public.has_role(array['admin','proyectos','ventas']))
  with check (public.has_role(array['admin','proyectos','ventas']));

-- Templates seed (los mas comunes)
insert into cotizacion_plantillas (nombre, descripcion, categoria, icono, items) values
  ('Cableado estructurado típico', 'Plantilla base para cotización de cableado estructurado', 'IT', '🔌',
   '[
     {"tipo":"material","cantidad":100,"unidad":"un","descripcion":"P.CORD CAT.6 3.0 MT","precio_unitario":12.89},
     {"tipo":"material","cantidad":200,"unidad":"un","descripcion":"JACK RJ45 CAT.6","precio_unitario":8.65},
     {"tipo":"material","cantidad":3,"unidad":"un","descripcion":"PATCH PANEL 48 PUERTOS","precio_unitario":150.13},
     {"tipo":"equipo","cantidad":2,"unidad":"un","descripcion":"Switch 24 poe + Lic.","precio_unitario":5500},
     {"tipo":"mano_obra","cantidad":150,"unidad":"boca","descripcion":"Mano de obra sin bandeja","precio_unitario":110}
   ]'::jsonb),
  ('CCTV básico (8 cámaras)', 'Sistema de CCTV con 8 cámaras IP', 'Seguridad', '📹',
   '[
     {"tipo":"equipo","cantidad":1,"unidad":"un","descripcion":"NVR 16 canales","precio_unitario":3500},
     {"tipo":"equipo","cantidad":8,"unidad":"un","descripcion":"Cámara IP 4mpx","precio_unitario":250},
     {"tipo":"material","cantidad":300,"unidad":"mts","descripcion":"Cable UTP CAT6","precio_unitario":1.03},
     {"tipo":"material","cantidad":2,"unidad":"un","descripcion":"Switch 8 puertos PoE","precio_unitario":850},
     {"tipo":"material","cantidad":1,"unidad":"un","descripcion":"HDD 4TB","precio_unitario":180},
     {"tipo":"mano_obra","cantidad":8,"unidad":"camara","descripcion":"Instalación y configuración","precio_unitario":120}
   ]'::jsonb)
on conflict do nothing;

select 'Plantillas de cotizacion listas' as status;
