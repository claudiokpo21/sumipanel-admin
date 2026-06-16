-- =============================================================
-- Resetear la clave del usuario admin@sumipanel.com
-- Pegar en SQL Editor y correr
-- =============================================================

-- Opcion A: Setear una clave especifica directamente
-- Cambia 'TuPasswordNueva2026!' por la que vos quieras
update auth.users
set encrypted_password = crypt('TuPasswordNueva2026!', gen_salt('bf'))
where email = 'admin@sumipanel.com';

-- Verificar
select id, email, updated_at
from auth.users
where email = 'admin@sumipanel.com';

select 'Clave actualizada. Usuario: admin@sumipanel.com | Clave: TuPasswordNueva2026!' as mensaje;
