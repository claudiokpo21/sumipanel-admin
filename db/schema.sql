-- =============================================================
-- SUMIPANEL ADMIN — Schema completo
-- Pegar en: Supabase Dashboard → SQL Editor → New query → Run
-- =============================================================

-- 0. Extensiones necesarias
create extension if not exists "pgcrypto";

-- =============================================================
-- 1. PERFILES DE USUARIO (vinculado a auth.users)
-- =============================================================
create table if not exists public.profiles (
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

-- Trigger: crear perfil automáticamente al registrarse
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'role', 'tecnico')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================
-- 2. MÓDULO COMERCIAL: clientes y proveedores
-- =============================================================
create table if not exists public.clientes (
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

create table if not exists public.proveedores (
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

-- =============================================================
-- 3. PRODUCTOS / STOCK
-- =============================================================
create table if not exists public.productos (
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

create table if not exists public.movimientos_stock (
  id bigserial primary key,
  producto_id bigint not null references public.productos(id) on delete restrict,
  tipo text not null check (tipo in ('ingreso','egreso','ajuste','reserva')),
  cantidad numeric(12,2) not null,
  referencia text,  -- ej: "OC-2026-0001" o "PED-2026-0001"
  motivo text,
  usuario_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- =============================================================
-- 4. PEDIDOS DE CLIENTES
-- =============================================================
create table if not exists public.pedidos (
  id bigserial primary key,
  folio text not null unique,
  cliente_id bigint references public.clientes(id),
  cliente_nombre text not null,  -- denormalizado para velocidad
  estado text not null default 'nuevo'
    check (estado in ('nuevo','confirmado','preparacion','despachado','entregado','cancelado')),
  total numeric(14,2) not null default 0,
  notas text,
  vendedor_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pedido_items (
  id bigserial primary key,
  pedido_id bigint not null references public.pedidos(id) on delete cascade,
  producto_id bigint references public.productos(id),
  sku text not null,
  nombre text not null,
  cantidad numeric(12,2) not null,
  precio numeric(14,2) not null,
  subtotal numeric(14,2) not null
);

-- =============================================================
-- 5. VENTAS (comprobantes emitidos)
-- =============================================================
create table if not exists public.ventas (
  id bigserial primary key,
  comprobante text not null unique,
  pedido_id bigint references public.pedidos(id),
  cliente_id bigint references public.clientes(id),
  cliente_nombre text not null,
  cuit text,
  subtotal numeric(14,2) not null,
  iva numeric(14,2) not null,
  total numeric(14,2) not null,
  forma_pago text not null,
  notas text,
  vendedor_id uuid references public.profiles(id),
  fecha timestamptz not null default now()
);

-- =============================================================
-- 6. COMPRAS (Órdenes de Compra) + Seguimiento
-- =============================================================
create table if not exists public.compras (
  id bigserial primary key,
  folio text not null unique,
  proveedor_id bigint not null references public.proveedores(id),
  estado text not null default 'solicitada'
    check (estado in ('solicitada','aprobada','enviada','transito','aduana','recibida','validada','cerrada','rechazada','cancelada')),
  total numeric(14,2) not null default 0,
  eta date,
  solicitante_id uuid references public.profiles(id),
  aprobador_id uuid references public.profiles(id),
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.compra_items (
  id bigserial primary key,
  compra_id bigint not null references public.compras(id) on delete cascade,
  producto_id bigint references public.productos(id),
  sku text not null,
  nombre text not null,
  cantidad numeric(12,2) not null,
  precio numeric(14,2) not null,
  subtotal numeric(14,2) not null
);

-- Tracking granular de la OC
create table if not exists public.compra_eventos (
  id bigserial primary key,
  compra_id bigint not null references public.compras(id) on delete cascade,
  estado text not null,
  comentario text,
  ubicacion text,  -- ej: "Puerto de Buenos Aires"
  foto_url text,
  usuario_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- =============================================================
-- 7. RECEPCIONES
-- =============================================================
create table if not exists public.recepciones (
  id bigserial primary key,
  folio text not null unique,
  compra_id bigint not null references public.compras(id),
  conformidad text not null default 'ok'
    check (conformidad in ('ok','parcial','observada','rechazada')),
  notas text,
  receptor_id uuid references public.profiles(id),
  fecha timestamptz not null default now()
);

create table if not exists public.recepcion_items (
  id bigserial primary key,
  recepcion_id bigint not null references public.recepciones(id) on delete cascade,
  sku text not null,
  nombre text not null,
  cantidad_pedida numeric(12,2) not null,
  cantidad_recibida numeric(12,2) not null,
  conforme boolean not null default true,
  observacion text
);

-- =============================================================
-- 8. PROYECTOS IT
-- =============================================================
create table if not exists public.proyectos (
  id bigserial primary key,
  codigo text not null unique,
  nombre text not null,
  cliente_id bigint references public.clientes(id),
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
  avance numeric(5,2) default 0,  -- 0-100
  responsable_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.proyecto_equipo (
  proyecto_id bigint not null references public.proyectos(id) on delete cascade,
  usuario_id uuid not null references public.profiles(id) on delete cascade,
  rol text default 'colaborador',
  horas_asignadas numeric(10,2),
  primary key (proyecto_id, usuario_id)
);

-- Alcances técnicos
create table if not exists public.alcances (
  id bigserial primary key,
  proyecto_id bigint not null references public.proyectos(id) on delete cascade,
  codigo text,
  titulo text not null,
  descripcion text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','en_curso','entregado','validado','rechazado')),
  prioridad text default 'media',
  horas_estimadas numeric(10,2),
  horas_reales numeric(10,2) default 0,
  responsable_id uuid references public.profiles(id),
  fecha_inicio date,
  fecha_fin date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.alcance_comentarios (
  id bigserial primary key,
  alcance_id bigint not null references public.alcances(id) on delete cascade,
  usuario_id uuid references public.profiles(id),
  texto text not null,
  created_at timestamptz not null default now()
);

-- Tareas (pueden ser de un alcance o independientes)
create table if not exists public.tareas (
  id bigserial primary key,
  proyecto_id bigint references public.proyectos(id) on delete cascade,
  alcance_id bigint references public.alcances(id) on delete cascade,
  titulo text not null,
  descripcion text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','en_curso','bloqueada','completada','cancelada')),
  prioridad text default 'media',
  asignado_id uuid references public.profiles(id),
  creador_id uuid references public.profiles(id),
  fecha_limite date,
  horas_estimadas numeric(10,2),
  horas_reales numeric(10,2) default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tarea_comentarios (
  id bigserial primary key,
  tarea_id bigint not null references public.tareas(id) on delete cascade,
  usuario_id uuid references public.profiles(id),
  texto text not null,
  created_at timestamptz not null default now()
);

-- =============================================================
-- 9. LOG / BITÁCORA CENTRALIZADA
-- =============================================================
create table if not exists public.log_eventos (
  id bigserial primary key,
  usuario_id uuid references public.profiles(id),
  usuario_email text,
  tipo text not null,  -- pedido, compra, recepcion, venta, stock, proyecto, alcance, tarea, auth, sistema
  accion text not null,
  detalle text,
  ref_codigo text,  -- folio o código afectado
  metadata jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_log_created on public.log_eventos(created_at desc);
create index if not exists idx_log_tipo on public.log_eventos(tipo);
create index if not exists idx_log_usuario on public.log_eventos(usuario_id);

-- =============================================================
-- 10. ROLES Y PERMISOS (helper)
-- =============================================================
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
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role='admin' and active=true);
$$;

-- =============================================================
-- 11. ROW LEVEL SECURITY
-- =============================================================
alter table public.profiles enable row level security;
alter table public.clientes enable row level security;
alter table public.proveedores enable row level security;
alter table public.productos enable row level security;
alter table public.movimientos_stock enable row level security;
alter table public.pedidos enable row level security;
alter table public.pedido_items enable row level security;
alter table public.ventas enable row level security;
alter table public.compras enable row level security;
alter table public.compra_items enable row level security;
alter table public.compra_eventos enable row level security;
alter table public.recepciones enable row level security;
alter table public.recepcion_items enable row level security;
alter table public.proyectos enable row level security;
alter table public.proyecto_equipo enable row level security;
alter table public.alcances enable row level security;
alter table public.alcance_comentarios enable row level security;
alter table public.tareas enable row level security;
alter table public.tarea_comentarios enable row level security;
alter table public.log_eventos enable row level security;

-- Helper: roles con acceso total de lectura y escritura
-- admin: todo
-- gerencia: lee todo, no edita config (usuarios)
-- compras: OC, proveedores, productos (lectura)
-- deposito: recepciones, productos, OC (lectura)
-- ventas: pedidos, ventas, clientes, productos (lectura)
-- proyectos: proyectos, alcances, tareas (de los suyos)
-- tecnico: solo sus tareas y proyectos asignados

-- PROFILES
create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);
create policy "profiles_update_self" on public.profiles
  for update to authenticated using (id = auth.uid());
create policy "profiles_admin_all" on public.profiles
  for all to authenticated using (public.is_admin());

-- CLIENTES / PROVEEDORES: lectura para todos los autenticados, escritura admin+compras+ventas
create policy "clientes_read" on public.clientes for select to authenticated using (true);
create policy "clientes_write" on public.clientes for all to authenticated
  using (public.has_role(array['admin','compras','ventas']))
  with check (public.has_role(array['admin','compras','ventas']));

create policy "proveedores_read" on public.proveedores for select to authenticated using (true);
create policy "proveedores_write" on public.proveedores for all to authenticated
  using (public.has_role(array['admin','compras']))
  with check (public.has_role(array['admin','compras']));

-- PRODUCTOS: lectura para todos, escritura admin+deposito+compras
create policy "productos_read" on public.productos for select to authenticated using (true);
create policy "productos_write" on public.productos for all to authenticated
  using (public.has_role(array['admin','deposito','compras']))
  with check (public.has_role(array['admin','deposito','compras']));

create policy "mov_stock_read" on public.movimientos_stock for select to authenticated using (true);
create policy "mov_stock_write" on public.movimientos_stock for insert to authenticated
  with check (public.has_role(array['admin','deposito','compras']));

-- PEDIDOS
create policy "pedidos_read" on public.pedidos for select to authenticated
  using (
    public.has_role(array['admin','gerencia','ventas','deposito','compras'])
    or vendedor_id = auth.uid()
  );
create policy "pedidos_write" on public.pedidos for all to authenticated
  using (public.has_role(array['admin','ventas','gerencia']))
  with check (public.has_role(array['admin','ventas','gerencia']));

create policy "pedido_items_read" on public.pedido_items for select to authenticated
  using (exists(select 1 from public.pedidos p where p.id = pedido_id));
create policy "pedido_items_write" on public.pedido_items for all to authenticated
  using (public.has_role(array['admin','ventas','gerencia']))
  with check (public.has_role(array['admin','ventas','gerencia']));

-- VENTAS
create policy "ventas_read" on public.ventas for select to authenticated
  using (public.has_role(array['admin','gerencia','ventas']));
create policy "ventas_write" on public.ventas for all to authenticated
  using (public.has_role(array['admin','ventas']))
  with check (public.has_role(array['admin','ventas']));

-- COMPRAS
create policy "compras_read" on public.compras for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
create policy "compras_write" on public.compras for all to authenticated
  using (public.has_role(array['admin','compras','gerencia']))
  with check (public.has_role(array['admin','compras','gerencia']));

create policy "compra_items_read" on public.compra_items for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
create policy "compra_items_write" on public.compra_items for all to authenticated
  using (public.has_role(array['admin','compras']))
  with check (public.has_role(array['admin','compras']));

create policy "compra_eventos_read" on public.compra_eventos for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
create policy "compra_eventos_write" on public.compra_eventos for insert to authenticated
  with check (public.has_role(array['admin','compras','deposito']));

-- RECEPCIONES
create policy "recepciones_read" on public.recepciones for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
create policy "recepciones_write" on public.recepciones for all to authenticated
  using (public.has_role(array['admin','deposito']))
  with check (public.has_role(array['admin','deposito']));

create policy "recepcion_items_read" on public.recepcion_items for select to authenticated
  using (public.has_role(array['admin','gerencia','compras','deposito']));
create policy "recepcion_items_write" on public.recepcion_items for all to authenticated
  using (public.has_role(array['admin','deposito']))
  with check (public.has_role(array['admin','deposito']));

-- PROYECTOS: lectura para todos los autenticados, escritura admin+proyectos+gerencia
-- Tecnicos solo ven los proyectos donde estan asignados
create policy "proyectos_read" on public.proyectos for select to authenticated
  using (
    public.has_role(array['admin','gerencia','ventas','compras','deposito','proyectos'])
    or exists(select 1 from public.proyecto_equipo pe where pe.proyecto_id = id and pe.usuario_id = auth.uid())
    or responsable_id = auth.uid()
  );
create policy "proyectos_write" on public.proyectos for all to authenticated
  using (public.has_role(array['admin','proyectos','gerencia']))
  with check (public.has_role(array['admin','proyectos','gerencia']));

create policy "proyecto_equipo_read" on public.proyecto_equipo for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or usuario_id = auth.uid()
  );
create policy "proyecto_equipo_write" on public.proyecto_equipo for all to authenticated
  using (public.has_role(array['admin','proyectos']))
  with check (public.has_role(array['admin','proyectos']));

-- ALCANCES
create policy "alcances_read" on public.alcances for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or exists(select 1 from public.proyectos p
              join public.proyecto_equipo pe on pe.proyecto_id = p.id
              where p.id = proyecto_id and pe.usuario_id = auth.uid())
    or responsable_id = auth.uid()
  );
create policy "alcances_write" on public.alcances for all to authenticated
  using (public.has_role(array['admin','proyectos']))
  with check (public.has_role(array['admin','proyectos']));

create policy "alcance_com_read" on public.alcance_comentarios for select to authenticated using (true);
create policy "alcance_com_write" on public.alcance_comentarios for insert to authenticated
  with check (public.has_role(array['admin','proyectos','gerencia','tecnico']));

-- TAREAS
create policy "tareas_read" on public.tareas for select to authenticated
  using (
    public.has_role(array['admin','gerencia','proyectos'])
    or asignado_id = auth.uid()
    or creador_id = auth.uid()
  );
create policy "tareas_write" on public.tareas for all to authenticated
  using (
    public.has_role(array['admin','proyectos'])
    or asignado_id = auth.uid()
  )
  with check (
    public.has_role(array['admin','proyectos'])
    or asignado_id = auth.uid()
  );

create policy "tarea_com_read" on public.tarea_comentarios for select to authenticated
  using (exists(select 1 from public.tareas t where t.id = tarea_id));
create policy "tarea_com_write" on public.tarea_comentarios for insert to authenticated
  with check (true);

-- LOG: lectura admin/gerencia, insercion cualquiera (registra sus propias acciones via trigger)
create policy "log_read" on public.log_eventos for select to authenticated
  using (public.has_role(array['admin','gerencia']));
create policy "log_insert" on public.log_eventos for insert to authenticated
  with check (true);

-- =============================================================
-- 12. DATOS SEMILLA (productos, clientes, proveedores demo)
-- =============================================================
insert into public.clientes (razon, cuit, email, tel) values
  ('Construcciones del Plata', '30-71234567-8', 'compras@delplata.com.ar', '+54 11 4555-1010'),
  ('Hierro Centro SRL', '30-70123456-7', 'cd@hierrocentro.com', '+54 11 4322-7788'),
  ('Metalúrgica Austral', '30-65432109-2', 'contacto@metaustral.com', '+54 11 4677-9090')
on conflict do nothing;

insert into public.proveedores (razon, cuit, contacto, email, tel) values
  ('Aceros del Sur SA', '30-70111222-3', 'Roberto Méndez', 'rmendez@acerossur.com', '+54 11 4488-2233'),
  ('Bulonera Industrial', '30-70888999-1', 'Lucía Pérez', 'lp@bulonera.com.ar', '+54 11 4655-3322'),
  ('Pinturas Andinas', '30-70555444-6', 'Diego Suárez', 'ds@pinturasandinas.com', '+54 11 4200-1100')
on conflict do nothing;

insert into public.productos (sku, nombre, categoria, stock, stock_min, precio_venta, costo) values
  ('CH-001', 'Chapa galvanizada 1.22x2.44 cal 22', 'Chapas', 120, 50, 22500, 18500),
  ('PR-010', 'Perfil C 100x50x2mm x 6m', 'Perfiles', 42, 30, 28900, 24000),
  ('TL-200', 'Tornillo autoperforante 1/4 x 2"', 'Bulonería', 8, 50, 480, 320),
  ('PB-050', 'Pintura antioxido 4L negro', 'Pinturas', 24, 15, 17900, 14800),
  ('PL-300', 'Plancha lisa 3mm 1x2m', 'Chapas', 3, 10, 31200, 26800)
on conflict (sku) do nothing;

-- =============================================================
-- 13. STORAGE para fotos de seguimiento
-- =============================================================
-- Crear bucket desde la UI: Storage → New bucket → "compra-fotos" → Public
-- (Lo dejo manual porque requiere UI click)

-- =============================================================
-- 14. VIEWS ÚTILES
-- =============================================================
create or replace view public.v_pedidos_detalle as
  select p.*, c.razon as cliente_razon_real,
         (select count(*) from public.pedido_items pi where pi.pedido_id = p.id) as items_count
  from public.pedidos p
  left join public.clientes c on c.id = p.cliente_id;

create or replace view public.v_compras_detalle as
  select co.*, pr.razon as proveedor_razon,
         (select count(*) from public.compra_items ci where ci.compra_id = co.id) as items_count,
         (select max(created_at) from public.compra_eventos ce where ce.compra_id = co.id) as ultimo_evento
  from public.compras co
  join public.proveedores pr on pr.id = co.proveedor_id;

create or replace view public.v_proyectos_detalle as
  select pr.*, cl.razon as cliente_razon,
         p.full_name as responsable_nombre,
         (select count(*) from public.alcances a where a.proyecto_id = pr.id) as alcances_count,
         (select count(*) from public.tareas t where t.proyecto_id = pr.id) as tareas_count,
         (select count(*) from public.proyecto_equipo pe where pe.proyecto_id = pr.id) as equipo_count
  from public.proyectos pr
  left join public.clientes cl on cl.id = pr.cliente_id
  left join public.profiles p on p.id = pr.responsable_id;

-- =============================================================
-- 15. TRIGGERS DE UPDATED_AT
-- =============================================================
create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists tg_profiles_updated on public.profiles;
create trigger tg_profiles_updated before update on public.profiles
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_productos_updated on public.productos;
create trigger tg_productos_updated before update on public.productos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_pedidos_updated on public.pedidos;
create trigger tg_pedidos_updated before update on public.pedidos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_compras_updated on public.compras;
create trigger tg_compras_updated before update on public.compras
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_proyectos_updated on public.proyectos;
create trigger tg_proyectos_updated before update on public.proyectos
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_alcances_updated on public.alcances;
create trigger tg_alcances_updated before update on public.alcances
  for each row execute function public.tg_touch_updated_at();

drop trigger if exists tg_tareas_updated on public.tareas;
create trigger tg_tareas_updated before update on public.tareas
  for each row execute function public.tg_touch_updated_at();

-- =============================================================
-- LISTO. Verificar con:
--   select table_name from information_schema.tables
--   where table_schema='public' order by table_name;
-- =============================================================
