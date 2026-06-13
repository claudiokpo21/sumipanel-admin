-- =============================================================
-- Fix: funciones helpers apuntan a sumipanel.profiles
-- (EncantoPropio no tiene public.profiles, usamos la nuestra)
-- Pegar en SQL Editor y correr
-- =============================================================

-- Reemplazar funcion has_role
create or replace function public.has_role(roles text[])
returns boolean
language sql
stable
security definer
set search_path = sumipanel, public
as $$
  select exists(
    select 1 from sumipanel.profiles
    where id = auth.uid()
      and role = any(roles)
      and active = true
  );
$$;

-- Reemplazar funcion is_admin
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = sumipanel, public
as $$
  select exists(
    select 1 from sumipanel.profiles
    where id = auth.uid() and role='admin' and active=true
  );
$$;

-- tg_touch_updated_at no usa profiles, pero por las dudas la dejamos
-- (la del schema ya quedo creada)

-- Verificacion: las funciones existen?
select proname, pronargs
from pg_proc
where proname in ('has_role','is_admin','tg_touch_updated_at','handle_new_user');

select 'OK - funciones corregidas' as status;
