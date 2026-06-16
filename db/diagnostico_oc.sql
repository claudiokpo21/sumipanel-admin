-- =============================================================
-- Diagnostico: Cotizaciones que se crearon pero no se ven
-- Pegar en SQL Editor y correr
-- =============================================================

-- 1) Ver TODAS las cotizaciones (sin filtro de RLS, somos admin del proyecto)
select id, folio, titulo, version, estado, proyecto_id, total, created_at
from cotizaciones
order by created_at desc
limit 20;

-- 2) Ver especificamente las del proyecto DATACENTER
select c.id, c.folio, c.titulo, c.estado, c.total, c.created_at, c.proyecto_id, p.nombre as proyecto
from cotizaciones c
left join proyectos p on p.id = c.proyecto_id
where p.nombre ilike '%datacenter%' or p.codigo ilike '%datacenter%' or p.codigo ilike '%PRY-06%'
order by c.created_at desc;

-- 3) Contar cotizaciones por proyecto
select p.nombre as proyecto, count(c.id) as total_cotizaciones
from proyectos p
left join cotizaciones c on c.proyecto_id = p.id
group by p.nombre
order by total_cotizaciones desc;

select 'Si ves cotizaciones aca que no aparecen en el panel, es problema de cache. Si NO ves ninguna, es problema de RLS o de que no se guardo.' as diagnostico;
