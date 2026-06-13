-- =============================================================
-- Plan B: mover todas las tablas de sumipanel a public
-- Esto es necesario si no podes exponer el schema via dashboard
-- Pegar y correr UNA vez
-- =============================================================

-- Mover cada tabla del schema sumipanel a public
do $$
declare
  r record;
  sql_text text;
begin
  for r in 
    select table_name 
    from information_schema.tables 
    where table_schema = 'sumipanel' 
      and table_type = 'BASE TABLE'
  loop
    sql_text := format('alter table sumipanel.%I set schema public', r.table_name);
    raise notice 'Moviendo: %', sql_text;
    execute sql_text;
  end loop;
end $$;

-- Verificacion: las tablas ahora estan en public
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

-- Actualizar las funciones helper para que apunten a public
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

-- Actualizar el trigger para que inserte en public.profiles
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

-- Recrear el trigger
drop trigger if exists on_auth_user_created_sumipanel on auth.users;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

select 'Migracion completa. Todas las tablas estan en public ahora.' as status;
