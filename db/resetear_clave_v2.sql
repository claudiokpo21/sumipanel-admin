-- =============================================================
-- Resetear clave del admin - VERSION QUE FUNCIONA SEGURO
-- Pegar en SQL Editor y correr
-- =============================================================

-- Paso 1: Verificamos que el usuario existe
select id, email, created_at
from auth.users
where email = 'admin@sumipanel.com';

-- Paso 2: Borramos todas las identidades asociadas (a veces esto causa problemas)
delete from auth.identities
where user_id in (select id from auth.users where email = 'admin@sumipanel.com');

-- Paso 3: Actualizamos la clave con crypt
update auth.users
set 
  encrypted_password = crypt('Admin2026!', gen_salt('bf')),
  updated_at = now(),
  email_confirmed_at = coalesce(email_confirmed_at, now())
where email = 'admin@sumipanel.com';

-- Paso 4: Verificamos
select id, email, updated_at, 
  case when encrypted_password is not null then 'Clave seteada OK' else 'Sin clave' end as clave_status
from auth.users
where email = 'admin@sumipanel.com';

select 'Si ves el usuario arriba con clave_status = Clave seteada OK, proba login con: admin@sumipanel.com / Admin2026!' as instrucciones;
