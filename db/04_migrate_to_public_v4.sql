-- =============================================================
-- MIGRACIÓN A PUBLIC - v4 (fix: handle_new_user duplicada)
-- Pegar y correr en SQL Editor
-- =============================================================

-- Paso 1: Mover todas las tablas de sumipanel a public
do $$
declare
  r record;
  move_count int := 0;
begin
  for r in 
    select table_name 
    from information_schema.tables 
    where table_schema = 'sumipanel' 
      and table_type = 'BASE TABLE'
  loop
    execute format('alter table sumipanel.%I set schema public', r.table_name);
    raise notice 'Moviendo: sumipanel.% a public', r.table_name;
    move_count := move_count + 1;
  end loop;
  raise notice 'Total tablas movidas: %', move_count;
end $$;

-- Paso 2: Si existe handle_new_user en sumipanel, dropearla (ya hay una en public)
do $$
begin
  if exists (
    select 1 from pg_proc p 
    join pg_namespace n on n.oid = p.pronamespace 
    where n.nspname = 'sumipanel' and p.proname = 'handle_new_user'
  ) then
    drop function sumipanel.handle_new_user() cascade;
    raise notice 'Funcion sumipanel.handle_new_user dropeada (la de public ya sirve)';
  end if;
end $$;

-- Paso 3: Asegurar que las funciones helper en public apuntan a public.profiles
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

-- Paso 4: Asegurar que public.handle_new_user existe y es correcta
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

-- Paso 5: Recrear el trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Paso 6: Eliminar el schema sumipanel vacio
drop schema if exists sumipanel cascade;

-- VERIFICACION FINAL
select '=== TABLAS EN PUBLIC ===' as seccion;
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

select '=== PERFIL ADMIN ===' as seccion;
select email, full_name, role, active 
from public.profiles 
where email = 'admin@sumipanel.com';

select '=== TRIGGER ===' as seccion;
select trigger_name, event_manipulation, action_timing
from information_schema.triggers
where event_object_schema = 'auth' 
  and event_object_table = 'users';

select 'Migracion completa. Recargá admin.html con Ctrl+Shift+R.' as status;
