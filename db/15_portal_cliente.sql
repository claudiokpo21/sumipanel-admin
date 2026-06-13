-- =============================================================
-- BLOQUE 15: Portal del Cliente (Clear)
-- Tablas para magic links, comentarios y aprobaciones
-- Pegar en SQL Editor y correr
-- =============================================================

-- Magic links: cada cliente puede tener varios, con expiracion
create table if not exists portal_access (
  id bigserial primary key,
  token text not null unique,             -- el string que va en la URL
  cliente_id bigint not null references clientes(id) on delete cascade,
  proyecto_id bigint references proyectos(id) on delete cascade,  -- opcional: acceso a un proyecto especifico
  email text not null,                    -- a quien le mandamos el link
  descripcion text,                        -- ej: "Acceso para Cotización Cableado Edificio Norte"
  activo boolean not null default true,
  expira_en timestamptz,                  -- null = sin expiracion
  ultimo_acceso timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index if not exists idx_portal_token on portal_access(token);
create index if not exists idx_portal_cliente on portal_access(cliente_id);
alter table portal_access enable row level security;

-- El portal es anon (sin login), por eso permitimos SELECT por token
-- PERO solo si esta activo y (no expiro o expira en el futuro)
drop policy if exists "sp_portal_read" on portal_access;
create policy "sp_portal_read" on portal_access
  for select to anon, authenticated
  using (
    activo = true
    and (expira_en is null or expira_en > now())
  );
-- Solo admins/gerencia pueden crear/modificar
drop policy if exists "sp_portal_write" on portal_access;
create policy "sp_portal_write" on portal_access
  for all to authenticated
  using (has_role(array['admin','gerencia','ventas']))
  with check (has_role(array['admin','gerencia','ventas']));

-- Comentarios/respuestas del cliente (en el portal, sin login)
create table if not exists portal_comentarios (
  id bigserial primary key,
  portal_id bigint not null references portal_access(id) on delete cascade,
  cotizacion_id bigint references cotizaciones(id) on delete cascade,
  proyecto_id bigint references proyectos(id) on delete cascade,
  autor_nombre text not null,
  autor_email text,
  texto text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_portal_com_portal on portal_comentarios(portal_id);
alter table portal_comentarios enable row level security;

-- Anon puede insertar (es el cliente desde el portal)
drop policy if exists "sp_portalcom_read" on portal_comentarios;
create policy "sp_portalcom_read" on portal_comentarios
  for select to anon, authenticated using (true);
drop policy if exists "sp_portalcom_insert" on portal_comentarios;
create policy "sp_portalcom_insert" on portal_comentarios
  for insert to anon, authenticated with check (true);

-- Aprobaciones / rechazo de cotizaciones desde el portal
create table if not exists portal_aprobaciones (
  id bigserial primary key,
  portal_id bigint not null references portal_access(id) on delete cascade,
  cotizacion_id bigint not null references cotizaciones(id) on delete cascade,
  decision text not null check (decision in ('aprobada','rechazada','comentario')),
  comentario text,
  firmado_por text,                       -- nombre de quien aprueba
  created_at timestamptz not null default now()
);
alter table portal_aprobaciones enable row level security;
drop policy if exists "sp_aprob_read" on portal_aprobaciones;
create policy "sp_aprob_read" on portal_aprobaciones
  for select to anon, authenticated using (true);
drop policy if exists "sp_aprob_insert" on portal_aprobaciones;
create policy "sp_aprob_insert" on portal_aprobaciones
  for insert to anon, authenticated with check (true);

-- Funcion helper: obtener datos del cliente por token
create or replace function public.portal_get_data(p_token text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_access portal_access%rowtype;
  v_cliente clientes%rowtype;
  v_proyectos json;
  v_cotizaciones json;
  result json;
begin
  select * into v_access from portal_access
  where token = p_token and activo = true
    and (expira_en is null or expira_en > now());

  if not found then
    return json_build_object('error', 'Link invalido o expirado');
  end if;

  -- actualizar ultimo acceso
  update portal_access set ultimo_acceso = now() where id = v_access.id;

  select * into v_cliente from clientes where id = v_access.cliente_id;

  -- proyectos del cliente
  select json_agg(row_to_json(p)) into v_proyectos
  from (
    select id, codigo, nombre, descripcion, estado, prioridad,
           fecha_inicio, fecha_fin_estimada, avance, presupuesto
    from proyectos
    where cliente_id = v_access.cliente_id
    order by created_at desc
  ) p;

  -- cotizaciones del cliente
  select json_agg(row_to_json(c)) into v_cotizaciones
  from (
    select co.id, co.titulo, co.version, co.estado, co.moneda, co.tipo_cambio,
           co.vigencia_dias, co.fecha, co.notas, co.total,
           (select json_agg(row_to_json(ci)) from (
             select tipo, cantidad, unidad, descripcion, precio_unitario, subtotal
             from cotizacion_items where cotizacion_id = co.id order by orden
           ) ci) as items
    from cotizaciones co
    where co.proyecto_id in (select id from proyectos where cliente_id = v_access.cliente_id)
    order by co.created_at desc
  ) c;

  -- aprobaciones previas
  result := json_build_object(
    'portal', row_to_json(v_access),
    'cliente', row_to_json(v_cliente),
    'proyectos', coalesce(v_proyectos, '[]'::json),
    'cotizaciones', coalesce(v_cotizaciones, '[]'::json)
  );
  return result;
end;
$$;

-- Funcion: registrar aprobacion y actualizar estado de la cotizacion
create or replace function public.portal_aprobar_cotizacion(
  p_token text,
  p_cotizacion_id bigint,
  p_decision text,
  p_comentario text,
  p_firmado_por text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_access portal_access%rowtype;
begin
  select * into v_access from portal_access
  where token = p_token and activo = true
    and (expira_en is null or expira_en > now());

  if not found then
    return json_build_object('error', 'Link invalido o expirado');
  end if;

  insert into portal_aprobaciones (portal_id, cotizacion_id, decision, comentario, firmado_por)
  values (v_access.id, p_cotizacion_id, p_decision, p_comentario, p_firmado_por);

  if p_decision in ('aprobada','rechazada') then
    update cotizaciones set estado = p_decision where id = p_cotizacion_id;
  end if;

  return json_build_object('ok', true, 'decision', p_decision);
end;
$$;

select 'Schema del Portal Clear listo. Siguiente: deployar el HTML.' as status;
