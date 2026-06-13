-- =============================================================
-- MIGRACIÓN A PUBLIC - v3 (limpio, verificado)
-- Pegar en SQL Editor y correr UNA sola vez
-- =============================================================

-- Paso 1: Mover todas las tablas de sumipanel a public
do $$
declare
  r record;
  sql_text text;
  move_count int := 0;
begin
  for r in 
    select table_name 
    from information_schema.tables 
    where table_schema = 'sumipanel' 
      and table_type = 'BASE TABLE'
  loop
    sql_text := format('alter table sumipanel.%I set schema public', r.table_name);
    raise notice 'Moviendo: sumipanel.% a public', r.table_name;
    execute sql_text;
    move_count := move_count + 1;
  end loop;
  raise notice 'Total movidas: % tablas', move_count;
end $$;

-- Paso 2: Mover la funcion handle_new_user si esta en sumipanel
do $$
begin
  if exists (
    select 1 from pg_proc p 
    join pg_namespace n on n.oid = p.pronamespace 
    where n.nspname = 'sumipanel' and p.proname = 'handle_new_user'
  ) then
    alter function sumipanel.handle_new_user set schema public;
    raise notice 'Funcion handle_new_user movida a public';
  end if;
end $$;

-- Paso 3: Recrear las funciones helper en public apuntando a public.profiles
-- (por si quedaron mal definidas antes)
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

-- Paso 4: Recrear handle_new_user en public (limpio)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
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

-- Paso 5: Recrear trigger (drop el viejo y crear el nuevo)
drop trigger if exists on_auth_user_created_sumipanel on auth.users;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Paso 6: Eliminar el schema sumipanel vacio (limpieza)
drop schema if exists sumipanel cascade;

-- Verificacion final: las tablas deben estar en public
select 'Tablas SUMIPANEL en public:' as titulo;
select table_name 
from information_schema.tables 
where table_schema = 'public' 
  and table_name in (
    'profiles','clientes','proveedores','productos','movimientos_stock',
    'pedidos','pedido_items','ventas','compras','compra_items',
    'compra_eventos','recepciones','recepcion_items','proyectos',
    'proyecto_equipo','alcances','alcance_comentarios','tareas',
    'tarea_comentarios','log_eventos'
  )
order by table_name;

-- Confirmar que el perfil admin sigue
select email, full_name, role, active 
from public.profiles 
where email = 'admin@sumipanel.com';

select 'Migracion completa. Recargá el admin.html con Ctrl+Shift+R.' as status;
