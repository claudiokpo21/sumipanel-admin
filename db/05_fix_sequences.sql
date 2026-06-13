-- =============================================================
-- Fix: dar permiso de uso a las secuencias (autoincrement) de todas las tablas
-- Pegar y correr en SQL Editor
-- =============================================================

-- Otorgar USAGE y SELECT sobre todas las secuencias del schema public al rol authenticated
do $$
declare
  r record;
begin
  for r in
    select sequence_schema, sequence_name
    from information_schema.sequences
    where sequence_schema = 'public'
  loop
    execute format('grant usage, select on sequence %I.%I to authenticated', r.sequence_schema, r.sequence_name);
    raise notice 'Permiso dado a: %.%', r.sequence_schema, r.sequence_name;
  end loop;
end $$;

-- Verificacion: contar secuencias con permiso
select count(*) as secuencias_con_permiso
from information_schema.sequences
where sequence_schema = 'public';

select 'Listo. Probá crear la OC de nuevo.' as status;
