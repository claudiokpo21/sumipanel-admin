-- =============================================================
-- Exponer el schema 'sumipanel' en la API REST de Supabase
-- Pegar en SQL Editor y correr (UNA vez)
-- =============================================================

-- Opcion 1: usar la funcion que provee Supabase para esto
-- Esta funcion existe en proyectos nuevos y maneja el reinicio del API
do $$
declare
  current_schemas text;
begin
  -- Obtener la lista actual
  select string_agg(s, ',') into current_schemas
  from unnest(coalesce(
    (select array_agg(value) from pg_settings where name='pgrst.db_schemas'),
    array['public','graphql_public']
  )) as s;

  -- Si sumipanel no esta, agregarlo
  if current_schemas not like '%sumipanel%' then
    raise notice 'Agregando sumipanel a db_schemas';
    perform set_config('pgrst.db_schemas', current_schemas || ', sumipanel', false);
  else
    raise notice 'sumipanel ya esta en db_schemas';
  end if;
end $$;

-- Forzar el cambio persistiendo en postgresql.conf via alter database
-- (esto sobrevive reinicios)
alter database postgres set "pgrst.db_schemas" to 'public, graphql_public, sumipanel';

-- Recargar PostgREST
notify pgrst, 'reload config';

select 'Listo. Esperando 10 segundos para que PostgREST recargue.' as status;
select pg_sleep(10);
select 'PostgREST deberia estar recargado. Probá de nuevo.' as status;
