-- =============================================================
-- Exponer el schema 'sumipanel' en la API REST de Supabase
-- Pegar en SQL Editor y correr
-- =============================================================

-- Agregar 'sumipanel' a los schemas expuestos por la API
-- (db-schemas es la lista separada por comas de schemas visibles via PostgREST)
-- Primero, lo agregamos al final
update db_schemas 
set schemas = array_append(schemas, 'sumipanel')
where not ('sumipanel' = any(schemas));

-- Si la fila no existe (no deberia pasar en Supabase), la creamos
insert into db_schemas (schemas)
values (array['public', 'graphql_public', 'sumipanel'])
on conflict do nothing;

-- Verificacion
select * from db_schemas;

-- Si lo anterior no funciona (depende de la version), usar el metodo alternativo:
-- ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, sumipanel';
-- (esto requiere reiniciar PostgREST, Supabase lo hace solo al detectar el cambio)

select 'Schema sumipanel deberia estar expuesto ahora' as status;
