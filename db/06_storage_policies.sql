-- =============================================================
-- Fix: politicas RLS para el bucket compra-fotos
-- Pegar y correr en SQL Editor
-- =============================================================

-- Politicas para el bucket compra-fotos
-- Estructura: {folio_oc}/{timestamp}.{ext}
-- Quien puede subir: usuarios autenticados con rol admin, compras, deposito
-- Quien puede ver/descargar: cualquier autenticado (bucket es publico)

-- 1. SELECT (lectura): cualquier autenticado
drop policy if exists "compra-fotos select" on storage.objects;
create policy "compra-fotos select" on storage.objects
  for select to authenticated
  using ( bucket_id = 'compra-fotos' );

-- 2. INSERT (subir): admin, compras, deposito
drop policy if exists "compra-fotos insert" on storage.objects;
create policy "compra-fotos insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'compra-fotos'
    and public.has_role(array['admin','compras','deposito'])
  );

-- 3. UPDATE (sobreescribir): admin, compras, deposito
drop policy if exists "compra-fotos update" on storage.objects;
create policy "compra-fotos update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'compra-fotos'
    and public.has_role(array['admin','compras','deposito'])
  )
  with check (
    bucket_id = 'compra-fotos'
    and public.has_role(array['admin','compras','deposito'])
  );

-- 4. DELETE: solo admin
drop policy if exists "compra-fotos delete" on storage.objects;
create policy "compra-fotos delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'compra-fotos'
    and public.is_admin()
  );

-- Verificacion
select 'Politicas de compra-fotos creadas.' as status;
