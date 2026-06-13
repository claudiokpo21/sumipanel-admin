# SUMIPANEL Admin

Panel de administración interna para gestión de compras, ventas, stock, proyectos IT, alcances técnicos, tareas, seguimiento de OC y trazabilidad.

## Stack

- Frontend: HTML + CSS + JS vanilla (un solo archivo `admin.html`)
- Backend: Supabase (PostgreSQL + Auth + Storage)
- Hosting: Vercel

## Setup local

1. Clonar el repo
2. Abrir `admin.html` en el navegador (doble click)
3. Loguearse con las credenciales provistas

## Deploy

- Push a `main` → Vercel redespliega automáticamente
- URL: ver dashboard de Vercel

## Archivos

- `admin.html` — aplicación completa (login, sidebar, todos los módulos)
- `db/*.sql` — scripts de Supabase (schema, migraciones, políticas, fixes)
- `vercel.json` — config de Vercel (SPA fallback)

## Seguridad

- Las credenciales de Supabase están en el front (es la publishable key, es pública)
- **NUNCA** subir la `service_role` key
- El repo es privado
- RLS activado en todas las tablas: cada usuario ve solo lo que su rol le permite
