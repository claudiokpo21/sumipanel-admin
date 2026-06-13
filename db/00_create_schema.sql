-- =============================================================
-- Crear schema aislado para SUMIPANEL Admin dentro de EncantoPropio
-- Pegar en: SQL Editor → New query → Run
-- =============================================================

create schema if not exists sumipanel;

-- Permisos: el rol anon y authenticated necesitan acceso al schema
grant usage on schema sumipanel to anon, authenticated, service_role;

-- Por defecto las tablas nuevas se crean en sumipanel
-- (esto es solo para esta sesion, no persistente)
-- Las tablas del schema las crearemos con prefijo sumipanel.

select 'Schema sumipanel creado. OK' as status;
