-- =============================================================
-- Diagnostico: estructura real de la tabla cotizaciones
-- Pegar en SQL Editor y correr
-- =============================================================

-- 1) Ver la estructura completa de la tabla cotizaciones
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'cotizaciones'
order by ordinal_position;

-- 2) Ver si hay datos
select count(*) as total_registros from cotizaciones;

-- 3) Ver los primeros registros tal como estan
select * from cotizaciones limit 5;

select 'Mirar la columna 1 para ver que campos tiene. Si falta folio, ese es el problema.' as nota;
