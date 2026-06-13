-- =============================================================
-- SUMIPANEL ADMIN — Schema completo (dentro de schema "sumipanel")
-- Ejecutar DESPUÉS de 00_create_schema.sql
-- =============================================================

-- Todas las tablas van con prefijo "sumipanel." gracias al search_path de la sesion
set search_path = sumipanel, public;

-- Helpers: funciones accesibles desde cualquier schema
create or replace function public.has_role(roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid()
      and role = any(roles)
      and active = true
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role='admin' and active=true
  );
$$;

create or replace function public.tg_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Funcion para crear perfil automaticamente al registrarse un usuario
-- La guardamos en public (donde estan los perfiles de EncantoPropio)
-- PERO como tus perfiles estan en otro lado, primero verifico.

-- =============================================================
-- TABLAS
-- =============================================================

-- Perfiles: si EncantoPropio ya tiene su propia tabla profiles,
-- nosotros creamos la nuestra dentro de sumipanel
create table if not exists sumipanel.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  role text not null default 'tecnico'
    check (role in ('admin','gerencia','compras','deposito','ventas','proyectos','tecnico')),
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update on sumipanel.profiles to authenticated;

-- Trigger para crear perfil SUMIPANEL cuando se registre un usuario
-- (NO toca los perfiles de EncantoPropio)
create or replace function sumipanel.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = sumipanel, public
as $$
begin
  insert into sumipanel.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'sumipanel_role', 'tecnico')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_sumipanel on auth.users;
create trigger on_auth_user_created_sumipanel
  after insert on auth.users
  for each row execute function sumipanel.handle_new_user();

-- =============================================================
-- Comercial: clientes y proveedores
-- =============================================================
create table if not exists sumipanel.clientes (
  id bigserial primary key,
  razon text not null,
  cuit text,
  email text,
  tel text,
  direccion text,
  notas text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.clientes to authenticated;

create table if not exists sumipanel.proveedores (
  id bigserial primary key,
  razon text not null,
  cuit text,
  contacto text,
  email text,
  tel text,
  direccion text,
  notas text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.proveedores to authenticated;

-- =============================================================
-- Productos / Stock
-- =============================================================
create table if not exists sumipanel.productos (
  id bigserial primary key,
  sku text not null unique,
  nombre text not null,
  categoria text,
  unidad text default 'unidad',
  stock numeric(12,2) not null default 0,
  stock_min numeric(12,2) not null default 0,
  precio_venta numeric(14,2) default 0,
  costo numeric(14,2) default 0,
  ubicacion text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.productos to authenticated;

create table if not exists sumipanel.movimientos_stock (
  id bigserial primary key,
  producto_id bigint not null references sumipanel.productos(id) on delete restrict,
  tipo text not null check (tipo in ('ingreso','egreso','ajuste','reserva')),
  cantidad numeric(12,2) not null,
  referencia text,
  motivo text,
  usuario_id uuid references sumipanel.profiles(id),
  created_at timestamptz not null default now()
);
grant select, insert on sumipanel.movimientos_stock to authenticated;

-- =============================================================
-- Pedidos
-- =============================================================
create table if not exists sumipanel.pedidos (
  id bigserial primary key,
  folio text not null unique,
  cliente_id bigint references sumipanel.clientes(id),
  cliente_nombre text not null,
  estado text not null default 'nuevo'
    check (estado in ('nuevo','confirmado','preparacion','despachado','entregado','cancelado')),
  total numeric(14,2) not null default 0,
  notas text,
  vendedor_id uuid references sumipanel.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.pedidos to authenticated;

create table if not exists sumipanel.pedido_items (
  id bigserial primary key,
  pedido_id bigint not null references sumipanel.pedidos(id) on delete cascade,
  producto_id bigint references sumipanel.productos(id),
  sku text not null,
  nombre text not null,
  cantidad numeric(12,2) not null,
  precio numeric(14,2) not null,
  subtotal numeric(14,2) not null
);
grant select, insert, update, delete on sumipanel.pedido_items to authenticated;

-- =============================================================
-- Ventas
-- =============================================================
create table if not exists sumipanel.ventas (
  id bigserial primary key,
  comprobante text not null unique,
  pedido_id bigint references sumipanel.pedidos(id),
  cliente_id bigint references sumipanel.clientes(id),
  cliente_nombre text not null,
  cuit text,
  subtotal numeric(14,2) not null,
  iva numeric(14,2) not null,
  total numeric(14,2) not null,
  forma_pago text not null,
  notas text,
  vendedor_id uuid references sumipanel.profiles(id),
  fecha timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.ventas to authenticated;

-- =============================================================
-- Compras (OC) + Seguimiento
-- =============================================================
create table if not exists sumipanel.compras (
  id bigserial primary key,
  folio text not null unique,
  proveedor_id bigint not null references sumipanel.proveedores(id),
  estado text not null default 'solicitada'
    check (estado in ('solicitada','aprobada','enviada','transito','aduana','recibida','validada','cerrada','rechazada','cancelada')),
  total numeric(14,2) not null default 0,
  eta date,
  solicitante_id uuid references sumipanel.profiles(id),
  aprobador_id uuid references sumipanel.profiles(id),
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.compras to authenticated;

create table if not exists sumipanel.compra_items (
  id bigserial primary key,
  compra_id bigint not null references sumipanel.compras(id) on delete cascade,
  producto_id bigint references sumipanel.productos(id),
  sku text not null,
  nombre text not null,
  cantidad numeric(12,2) not null,
  precio numeric(14,2) not null,
  subtotal numeric(14,2) not null
);
grant select, insert, update, delete on sumipanel.compra_items to authenticated;

create table if not exists sumipanel.compra_eventos (
  id bigserial primary key,
  compra_id bigint not null references sumipanel.compras(id) on delete cascade,
  estado text not null,
  comentario text,
  ubicacion text,
  foto_url text,
  usuario_id uuid references sumipanel.profiles(id),
  created_at timestamptz not null default now()
);
grant select, insert on sumipanel.compra_eventos to authenticated;

-- =============================================================
-- Recepciones
-- =============================================================
create table if not exists sumipanel.recepciones (
  id bigserial primary key,
  folio text not null unique,
  compra_id bigint not null references sumipanel.compras(id),
  conformidad text not null default 'ok'
    check (conformidad in ('ok','parcial','observada','rechazada')),
  notas text,
  receptor_id uuid references sumipanel.profiles(id),
  fecha timestamptz not null default now()
);
grant select, insert, update on sumipanel.recepciones to authenticated;

create table if not exists sumipanel.recepcion_items (
  id bigserial primary key,
  recepcion_id bigint not null references sumipanel.recepciones(id) on delete cascade,
  sku text not null,
  nombre text not null,
  cantidad_pedida numeric(12,2) not null,
  cantidad_recibida numeric(12,2) not null,
  conforme boolean not null default true,
  observacion text
);
grant select, insert, update on sumipanel.recepcion_items to authenticated;

-- =============================================================
-- Proyectos IT
-- =============================================================
create table if not exists sumipanel.proyectos (
  id bigserial primary key,
  codigo text not null unique,
  nombre text not null,
  cliente_id bigint references sumipanel.clientes(id),
  cliente_nombre text,
  descripcion text,
  estado text not null default 'planificacion'
    check (estado in ('planificacion','en_curso','pausado','finalizado','cancelado')),
  prioridad text not null default 'media'
    check (prioridad in ('baja','media','alta','critica')),
  fecha_inicio date,
  fecha_fin_estimada date,
  fecha_fin_real date,
  presupuesto numeric(14,2),
  horas_estimadas numeric(10,2),
  horas_reales numeric(10,2) default 0,
  avance numeric(5,2) default 0,
  responsable_id uuid references sumipanel.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.proyectos to authenticated;

create table if not exists sumipanel.proyecto_equipo (
  proyecto_id bigint not null references sumipanel.proyectos(id) on delete cascade,
  usuario_id uuid not null references sumipanel.profiles(id) on delete cascade,
  rol text default 'colaborador',
  horas_asignadas numeric(10,2),
  primary key (proyecto_id, usuario_id)
);
grant select, insert, update, delete on sumipanel.proyecto_equipo to authenticated;

create table if not exists sumipanel.alcances (
  id bigserial primary key,
  proyecto_id bigint not null references sumipanel.proyectos(id) on delete cascade,
  codigo text,
  titulo text not null,
  descripcion text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','en_curso','entregado','validado','rechazado')),
  prioridad text default 'media',
  horas_estimadas numeric(10,2),
  horas_reales numeric(10,2) default 0,
  responsable_id uuid references sumipanel.profiles(id),
  fecha_inicio date,
  fecha_fin date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.alcances to authenticated;

create table if not exists sumipanel.alcance_comentarios (
  id bigserial primary key,
  alcance_id bigint not null references sumipanel.alcances(id) on delete cascade,
  usuario_id uuid references sumipanel.profiles(id),
  texto text not null,
  created_at timestamptz not null default now()
);
grant select, insert on sumipanel.alcance_comentarios to authenticated;

create table if not exists sumipanel.tareas (
  id bigserial primary key,
  proyecto_id bigint references sumipanel.proyectos(id) on delete cascade,
  alcance_id bigint references sumipanel.alcances(id) on delete cascade,
  titulo text not null,
  descripcion text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','en_curso','bloqueada','completada','cancelada')),
  prioridad text default 'media',
  asignado_id uuid references sumipanel.profiles(id),
  creador_id uuid references sumipanel.profiles(id),
  fecha_limite date,
  horas_estimadas numeric(10,2),
  horas_reales numeric(10,2) default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on sumipanel.tareas to authenticated;

create table if not exists sumipanel.tarea_comentarios (
  id bigserial primary key,
  tarea_id bigint not null references sumipanel.tareas(id) on delete cascade,
  usuario_id uuid references sumipanel.profiles(id),
  texto text not null,
  created_at timestamptz not null default now()
);
grant select, insert on sumipanel.tarea_comentarios to authenticated;

-- =============================================================
-- Log centralizado
-- =============================================================
create table if not exists sumipanel.log_eventos (
  id bigserial primary key,
  usuario_id uuid references sumipanel.profiles(id),
  usuario_email text,
  tipo text not null,
  accion text not null,
  detalle text,
  ref_codigo text,
  metadata jsonb,
  created_at timestamptz not null default now()
);
grant select, insert on sumipanel.log_eventos to authenticated;
create index if not exists idx_log_created on sumipanel.log_eventos(created_at desc);
create index if not exists idx_log_tipo on sumipanel.log_eventos(tipo);

-- =============================================================
-- RLS (Row Level Security)
-- =============================================================

alter table sumipanel.profiles enable row level security;
alter table sumipanel.clientes enable row level security;
alter table sumipanel.proveedores enable row level security;
alter table sumipanel.productos enable row level security;
alter table sumipanel.movimientos_stock enable row level security;
alter table sumipanel.pedidos enable row level security;
alter table sumipanel.pedido_items enable row level security;
alter table sumipanel.ventas enable row level security;
alter table sumipanel.compras enable row level security;
alter table sumipanel.compra_items enable row level security;
alter table sumipanel.compra_eventos enable row level security;
alter table sumipanel.recepciones enable row level security;
alter table sumipanel.recepcion_items enable row level security;
alter table sumipanel.proyectos enable row level security;
alter table sumipanel.proyecto_equipo enable row level security;
alter table sumipanel.alcances enable row level security;
alter table sumipanel.alcance_comentarios enable row level security;
alter table sumipanel.tareas enable row level security;
alter table sumipanel.tarea_comentarios enable row level security;
alter table sumipanel.log_eventos enable row level security;

-- Profiles
drop policy if exists "sp_profiles_select" on sumipanel.profiles;
create policy "sp_profiles_select" on sumipanel.profiles
  for select to authenticated using (true);
drop policy if exists "sp_profiles_update_self" on sumipanel.profiles;
create policy "sp_profiles_update_self" on sumipanel.profiles
  for update to authenticated using (id = auth.uid());
drop policy if exists "sp_profiles_admin" on sumipanel.profiles;
create policy "sp_profiles_admin" on sumipanel.profiles
  for all to authenticated using (public.is_admin());

-- Clientes / Proveedores
drop policy if exists "sp_clientes_read" on sumipanel.clientes;
create policy "sp_clientes_read" on sumipanel.clientes
  for select to authenticated using (true);
drop policy if exists "sp_clientes_write" on sumipanel.clientes;
create policy "sp_clientes_write" on sumipanel.clientes
  for all to authenticated
  using (public.has_role(array['admin','compras','ventas']))
  with check (public.has_role(array['admin','compras','ventas']));

drop policy if exists "sp_proveedores_read" on sumipanel.proveedores;
create policy "sp_proveedores_read" on sumipanel.proveedores
  for select to authenticated using (true);
drop policy if exists "sp_proveedores_write" on sumipanel.proveedores;
create policy "sp_proveedores_write" on sumipanel.proveedores
  for all to authenticated
  using (public.has_role(array['admin','compras']))
  with check (public.has_role(array['admin','compras']));

-- Productos / Stock
drop policy if exists "sp_productos_read" on sumipanel.productos;
create policy "sp_productos_read" on sumipanel.productos
  for select to authenticated using (true);
drop policy if exists "sp_productos_write" on sumipanel.productos;
create policy "sp_productos_write" on sumipanel.productos
  for all to authenticated
  using (public.has_role(array['admin','deposito','compras']))
  with check (public.has_role(array['admin','deposito','compras']));

drop policy if exists "sp_movstock_read" on sumipanel.movimientos_stock;
create policy "sp_movstock_read" on sumipanel.movimientos_stock
  for select to authenticated using (true);
drop policy if exists "sp_movstock_write" on sumipanel.movimientos_stock;
create policy "sp_movstock_write" on sumipanel.movimientos_stock
  for insert to authenticated
  with check (public.has_role(array['admin','deposito','compras']));

-- Pedidos
drop policy if exists "sp_pedidos_read" on sumipanel.pedidos;
create policy "sp_pedidos_read" on sumipanel.pedidos
  for select to authenticated
  using (
    public.has_role(array['admin','gerencia','ventas','deposito','compras'])
    or vendedor_id = auth.uid()
  );
drop policy if exists "sp_pedidos_write" on sumipanel.pedidos;
create policy "sp_pedidos_write" on sumipanel.pedidos
  for all to authenticated
  using (public.has_role(array['admin','ventas','gerencia']))
  with check (public.has_role(array['admin','ventas','gerencia']));

drop policy if exists "sp_peditems_read" on sumipanel.pedido_items;
create policy "sp_peditems_read" on sumipanel.pedido_items
  for select to authenticated using (true);
drop policy if exists "sp_peditems_write" on sumipanel.pedido_items;
create policy "sp_peditems_write" on sumipanel.pedido_items
  for all to authenticated
  using (public.has_role(array['admin','ventas','gerencia']))
  with check (public.has_role(array['admin','ventas','gerencia']));

-- Ventas
drop policy if exists "sp_ventas_read" on sumipanel.ventas;
create policy "sp_ventas_read" on sumipanel.ventas
  for select to authenticated
  using (public.has_role(array['admin','gerencia','ventas']));
drop policy if exists "sp_ventas_write" on sumipanel.ventas;
create policy "sp_ventas_write" on sumipanel.ventas
  for all to authenticated
  using (public.has_role(array['admin','ventas']))
  with check (public.has_role(array['admin','ventas']));

-- Compras
drop policy if exists "sp_compras_read" on sumipanel.compras;
create policy "sp_compras_read" on sumipanel.compras
  for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
drop policy if exists "sp_compras_write" on sumipanel.compras;
create policy "sp_compras_write" on sumipanel.compras
  for all to authenticated
  using (public.has_role(array['admin','compras','gerencia']))
  with check (public.has_role(array['admin','compras','gerencia']));

drop policy if exists "sp_compraitems_read" on sumipanel.compra_items;
create policy "sp_compraitems_read" on sumipanel.compra_items
  for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
drop policy if exists "sp_compraitems_write" on sumipanel.compra_items;
create policy "sp_compraitems_write" on sumipanel.compra_items
  for all to authenticated
  using (public.has_role(array['admin','compras']))
  with check (public.has_role(array['admin','compras']));

drop policy if exists "sp_compraeventos_read" on sumipanel.compra_eventos;
create policy "sp_compraeventos_read" on sumipanel.compra_eventos
  for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
drop policy if exists "sp_compraeventos_write" on sumipanel.compra_eventos;
create policy "sp_compraeventos_write" on sumipanel.compra_eventos
  for insert to authenticated
  with check (public.has_role(array['admin','compras','deposito']));

-- Recepciones
drop policy if exists "sp_recepciones_read" on sumipanel.recepciones;
create policy "sp_recepciones_read" on sumipanel.recepciones
  for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
drop policy if exists "sp_recepciones_write" on sumipanel.recepciones;
create policy "sp_recepciones_write" on sumipanel.recepciones
  for all to authenticated
  using (public.has_role(array['admin','deposito']))
  with check (public.has_role(array['admin','deposito']));

drop policy if exists "sp_recitems_read" on sumipanel.recepcion_items;
create policy "sp_recitems_read" on sumipanel.recepcion_items
  for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
drop policy if exists "sp_recitems_write" on sumipanel.recepcion_items;
create policy "sp_recitems_write" on sumipanel.recepcion_items
  for all to authenticated
  using (public.has_role(array['admin','deposito']))
  with check (public.has_role(array['admin','deposito']));

-- Proyectos
drop policy if exists "sp_proyectos_read" on sumipanel.proyectos;
create policy "sp_proyectos_read" on sumipanel.proyectos
  for select to authenticated
  using (
    public.has_role(array['admin','gerencia','ventas','compras','deposito','proyectos'])
    or responsable_id = auth.uid()
    or exists(select 1 from sumipanel.proyecto_equipo pe
              where pe.proyecto_id = id and pe.usuario_id = auth.uid())
  );
drop policy if exists "sp_proyectos_write" on sumipanel.proyectos;
create policy "sp_proyectos_write" on sumipanel.proyectos
  for all to authenticated
  using (public.has_role(array['admin','proyectos','gerencia']))
  with check (public.has_role(array['admin','proyectos','gerencia']));

drop policy if exists "sp_proyequipo_read" on sumipanel.proyecto_equipo;
create policy "sp_proyequipo_read" on sumipanel.proyecto_equipo
  for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or usuario_id = auth.uid()
  );
drop policy if exists "sp_proyequipo_write" on sumipanel.proyecto_equipo;
create policy "sp_proyequipo_write" on sumipanel.proyecto_equipo
  for all to authenticated
  using (public.has_role(array['admin','proyectos']))
  with check (public.has_role(array['admin','proyectos']));

-- Alcances
drop policy if exists "sp_alcances_read" on sumipanel.alcances;
create policy "sp_alcances_read" on sumipanel.alcances
  for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or responsable_id = auth.uid()
    or exists(select 1 from sumipanel.proyectos p
              join sumipanel.proyecto_equipo pe on pe.proyecto_id = p.id
              where p.id = proyecto_id and pe.usuario_id = auth.uid())
  );
drop policy if exists "sp_alcances_write" on sumipanel.alcances;
create policy "sp_alcances_write" on sumipanel.alcances
  for all to authenticated
  using (public.has_role(array['admin','proyectos']))
  with check (public.has_role(array['admin','proyectos']));

drop policy if exists "sp_alccom_read" on sumipanel.alcance_comentarios;
create policy "sp_alccom_read" on sumipanel.alcance_comentarios
  for select to authenticated using (true);
drop policy if exists "sp_alccom_write" on sumipanel.alcance_comentarios;
create policy "sp_alccom_write" on sumipanel.alcance_comentarios
  for insert to authenticated
  with check (public.has_role(array['admin','proyectos','gerencia','tecnico']));

-- Tareas
drop policy if exists "sp_tareas_read" on sumipanel.tareas;
create policy "sp_tareas_read" on sumipanel.tareas
  for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or asignado_id = auth.uid()
    or creador_id = auth.uid()
  );
drop policy if exists "sp_tareas_write" on sumipanel.tareas;
create policy "sp_tareas_write" on sumipanel.tareas
  for all to authenticated
  using (
    public.has_role(array['admin','proyectos'])
    or asignado_id = auth.uid()
  )
  with check (
    public.has_role(array['admin','proyectos'])
    or asignado_id = auth.uid()
  );

drop policy if exists "sp_tarcom_read" on sumipanel.tarea_comentarios;
create policy "sp_tarcom_read" on sumipanel.tarea_comentarios
  for select to authenticated using (true);
drop policy if exists "sp_tarcom_write" on sumipanel.tarea_comentarios;
create policy "sp_tarcom_write" on sumipanel.tarea_comentarios
  for insert to authenticated with check (true);

-- Log
drop policy if exists "sp_log_read" on sumipanel.log_eventos;
create policy "sp_log_read" on sumipanel.log_eventos
  for select to authenticated
  using (public.has_role(array['admin','gerencia']));
drop policy if exists "sp_log_insert" on sumipanel.log_eventos;
create policy "sp_log_insert" on sumipanel.log_eventos
  for insert to authenticated with check (true);

-- =============================================================
-- TRIGGERS updated_at
-- =============================================================
drop trigger if exists tg_profiles_updated on sumipanel.profiles;
create trigger tg_profiles_updated before update on sumipanel.profiles
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_productos_updated on sumipanel.productos;
create trigger tg_productos_updated before update on sumipanel.productos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_pedidos_updated on sumipanel.pedidos;
create trigger tg_pedidos_updated before update on sumipanel.pedidos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_compras_updated on sumipanel.compras;
create trigger tg_compras_updated before update on sumipanel.compras
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_proyectos_updated on sumipanel.proyectos;
create trigger tg_proyectos_updated before update on sumipanel.proyectos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_alcances_updated on sumipanel.alcances;
create trigger tg_alcances_updated before update on sumipanel.alcances
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_tareas_updated on sumipanel.tareas;
create trigger tg_tareas_updated before update on sumipanel.tareas
  for each row execute function public.tg_touch_updated_at();

-- =============================================================
-- DATOS SEMILLA
-- =============================================================
insert into sumipanel.clientes (razon, cuit, email, tel) values
  ('Construcciones del Plata', '30-71234567-8', 'compras@delplata.com.ar', '+54 11 4555-1010'),
  ('Hierro Centro SRL', '30-70123456-7', 'cd@hierrocentro.com', '+54 11 4322-7788'),
  ('Metalúrgica Austral', '30-65432109-2', 'contacto@metaustral.com', '+54 11 4677-9090')
on conflict do nothing;

insert into sumipanel.proveedores (razon, cuit, contacto, email, tel) values
  ('Aceros del Sur SA', '30-70111222-3', 'Roberto Méndez', 'rmendez@acerossur.com', '+54 11 4488-2233'),
  ('Bulonera Industrial', '30-70888999-1', 'Lucía Pérez', 'lp@bulonera.com.ar', '+54 11 4655-3322'),
  ('Pinturas Andinas', '30-70555444-6', 'Diego Suárez', 'ds@pinturasandinas.com', '+54 11 4200-1100')
on conflict do nothing;

insert into sumipanel.productos (sku, nombre, categoria, stock, stock_min, precio_venta, costo) values
  ('CH-001', 'Chapa galvanizada 1.22x2.44 cal 22', 'Chapas', 120, 50, 22500, 18500),
  ('PR-010', 'Perfil C 100x50x2mm x 6m', 'Perfiles', 42, 30, 28900, 24000),
  ('TL-200', 'Tornillo autoperforante 1/4 x 2"', 'Bulonería', 8, 50, 480, 320),
  ('PB-050', 'Pintura antioxido 4L negro', 'Pinturas', 24, 15, 17900, 14800),
  ('PL-300', 'Plancha lisa 3mm 1x2m', 'Chapas', 3, 10, 31200, 26800)
on conflict (sku) do nothing;

-- =============================================================
-- Verificacion final
-- =============================================================
select 'sumipanel' as schema, table_name
from information_schema.tables
where table_schema = 'sumipanel'
order by table_name;
