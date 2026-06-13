-- =============================================================
-- BLOQUE 10: Sistema de notificaciones por email
-- VERSION PUBLIC (todo en el schema public, no usa schema sumipanel)
-- Pegar en SQL Editor y correr
-- =============================================================

-- Configuracion de notificaciones por usuario
create table if not exists notif_config (
  usuario_id uuid primary key references profiles(id) on delete cascade,
  email_recepcion boolean not null default true,
  email_stock_critico boolean not null default true,
  email_tarea_asignada boolean not null default true,
  email_tarea_vencida boolean not null default true,
  email_oc_atrasada boolean not null default true,
  email_oc_cambio_estado boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table notif_config enable row level security;
drop policy if exists "sp_notifc_read" on notif_config;
create policy "sp_notifc_read" on notif_config
  for select to authenticated using (true);
drop policy if exists "sp_notifc_write" on notif_config;
create policy "sp_notifc_write" on notif_config
  for all to authenticated using (usuario_id = auth.uid() or is_admin())
  with check (usuario_id = auth.uid() or is_admin());

-- Cola de emails
create table if not exists notif_queue (
  id bigserial primary key,
  to_email text not null,
  to_name text,
  subject text not null,
  html_body text not null,
  tipo text not null,
  ref_codigo text,
  metadata jsonb,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','enviado','error','descartado')),
  intentos int default 0,
  ultimo_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists idx_notifq_estado on notif_queue(estado, created_at);
alter table notif_queue enable row level security;
drop policy if exists "sp_notifq_read" on notif_queue;
create policy "sp_notifq_read" on notif_queue
  for select to authenticated
  using (has_role(array['admin','gerencia']));
drop policy if exists "sp_notifq_insert" on notif_queue;
create policy "sp_notifq_insert" on notif_queue
  for insert to authenticated with check (true);

-- Trigger updated_at en notif_config
drop trigger if exists tg_notifc_updated on notif_config;
create trigger tg_notifc_updated before update on notif_config
  for each row execute function tg_touch_updated_at();

-- Asegurar que la funcion handle_new_user crea la config tambien
-- (sobrescribimos solo el cuerpo, no la firma)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'sumipanel_role', 'tecnico')
  )
  on conflict (id) do nothing;
  insert into public.notif_config (usuario_id)
  values (new.id)
  on conflict (usuario_id) do nothing;
  return new;
end;
$$;

-- Asegurar que el trigger existe
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================
-- FUNCION HELPER: encolar email
-- =============================================================
create or replace function public.enqueue_email(
  p_to text,
  p_to_name text,
  p_subject text,
  p_html text,
  p_tipo text,
  p_ref text default null,
  p_meta jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notif_queue (to_email, to_name, subject, html_body, tipo, ref_codigo, metadata)
  values (p_to, p_to_name, p_subject, p_html, p_tipo, p_ref, p_meta);
end;
$$;

-- =============================================================
-- TEMPLATES HTML
-- =============================================================
create or replace function public.template_recepcion(p_folio text, p_oc text, p_proveedor text, p_conformidad text, p_user_name text)
returns text
language sql
immutable
as $$
  select '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:600px;margin:0 auto;background:#0b0d12;color:#e6e9f2">
  <div style="background:linear-gradient(135deg,#7c5cff,#3b82f6);padding:24px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:22px">SUMIPANEL</h1>
  </div>
  <div style="padding:24px;background:#141822">
    <h2 style="margin:0 0 16px;color:#22d3a4">📦 Recepción registrada</h2>
    <p>Hola <b>' || p_user_name || '</b>,</p>
    <p>Se registró una nueva recepción en el sistema:</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px;color:#8a93a8">Recibo</td><td style="padding:8px"><b>' || p_folio || '</b></td></tr>
      <tr style="background:#0e1119"><td style="padding:8px;color:#8a93a8">OC</td><td style="padding:8px">' || p_oc || '</td></tr>
      <tr><td style="padding:8px;color:#8a93a8">Proveedor</td><td style="padding:8px">' || p_proveedor || '</td></tr>
      <tr style="background:#0e1119"><td style="padding:8px;color:#8a93a8">Conformidad</td><td style="padding:8px"><b>' || upper(p_conformidad) || '</b></td></tr>
    </table>
    <p style="margin-top:24px"><a href="https://sumipanel-admin.vercel.app" style="background:#7c5cff;color:#fff;padding:10px 20px;border-radius:6px;text-decoration:none;display:inline-block">Ver en el panel</a></p>
  </div>
  <div style="background:#0e1119;padding:16px;text-align:center;color:#5b6478;font-size:11px">SUMIPANEL · Notificación automática</div>
  </div>';
$$;

create or replace function public.template_stock_critico(p_productos text, p_user_name text)
returns text
language sql
immutable
as $$
  select '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:600px;margin:0 auto;background:#0b0d12;color:#e6e9f2">
  <div style="background:linear-gradient(135deg,#f5a524,#dc2626);padding:24px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:22px">⚠ Stock crítico</h1>
  </div>
  <div style="padding:24px;background:#141822">
    <p>Hola <b>' || p_user_name || '</b>,</p>
    <p>Los siguientes productos están bajo el stock mínimo:</p>
    <div style="background:#0e1119;padding:12px;border-left:3px solid #f5a524;margin:16px 0;font-family:monospace;font-size:13px;white-space:pre-line">' || p_productos || '</div>
    <p style="margin-top:24px"><a href="https://sumipanel-admin.vercel.app" style="background:#f5a524;color:#0b0d12;padding:10px 20px;border-radius:6px;text-decoration:none;display:inline-block;font-weight:600">Revisar stock</a></p>
  </div>
  <div style="background:#0e1119;padding:16px;text-align:center;color:#5b6478;font-size:11px">SUMIPANEL · Notificación automática</div>
  </div>';
$$;

create or replace function public.template_tarea(p_titulo text, p_user_name text, p_fecha_limite text, p_tipo text)
returns text
language sql
immutable
as $$
  select '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:600px;margin:0 auto;background:#0b0d12;color:#e6e9f2">
  <div style="background:linear-gradient(135deg,#3b82f6,#7c5cff);padding:24px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:22px">📋 ' || case when p_tipo = chr(39)||'asignada'||chr(39) then 'Nueva tarea' else 'Tarea ' || p_tipo end || '</h1>
  </div>
  <div style="padding:24px;background:#141822">
    <p>Hola <b>' || p_user_name || '</b>,</p>
    <p>' || case when p_tipo = chr(39)||'asignada'||chr(39) then 'Se te asignó una nueva tarea:' else 'Tenés una tarea ' || p_tipo || ':' end || '</p>
    <div style="background:#0e1119;padding:16px;border-radius:6px;margin:16px 0">
      <div style="font-size:18px;font-weight:600">' || p_titulo || '</div>
      <div style="margin-top:8px;color:#8a93a8">📅 Fecha límite: <b>' || p_fecha_limite || '</b></div>
    </div>
    <p style="margin-top:24px"><a href="https://sumipanel-admin.vercel.app" style="background:#3b82f6;color:#fff;padding:10px 20px;border-radius:6px;text-decoration:none;display:inline-block">Ver mis tareas</a></p>
  </div>
  <div style="background:#0e1119;padding:16px;text-align:center;color:#5b6478;font-size:11px">SUMIPANEL · Notificación automática</div>
  </div>';
$$;

create or replace function public.template_oc_atrasada(p_oc text, p_proveedor text, p_dias int, p_user_name text)
returns text
language sql
immutable
as $$
  select '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:600px;margin:0 auto;background:#0b0d12;color:#e6e9f2">
  <div style="background:linear-gradient(135deg,#dc2626,#7c2d12);padding:24px;text-align:center">
    <h1 style="color:#fff;margin:0;font-size:22px">🔴 OC atrasada</h1>
  </div>
  <div style="padding:24px;background:#141822">
    <p>Hola <b>' || p_user_name || '</b>,</p>
    <p>La siguiente orden de compra está atrasada y requiere atención:</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px;color:#8a93a8">OC</td><td style="padding:8px"><b>' || p_oc || '</b></td></tr>
      <tr style="background:#0e1119"><td style="padding:8px;color:#8a93a8">Proveedor</td><td style="padding:8px">' || p_proveedor || '</td></tr>
      <tr><td style="padding:8px;color:#8a93a8">Atraso</td><td style="padding:8px;color:#fca5a5"><b>' || p_dias || ' días</b></td></tr>
    </table>
    <p style="margin-top:24px"><a href="https://sumipanel-admin.vercel.app" style="background:#dc2626;color:#fff;padding:10px 20px;border-radius:6px;text-decoration:none;display:inline-block">Ver seguimiento</a></p>
  </div>
  <div style="background:#0e1119;padding:16px;text-align:center;color:#5b6478;font-size:11px">SUMIPANEL · Notificación automática</div>
  </div>';
$$;

-- =============================================================
-- TRIGGERS
-- =============================================================

-- 1) Recepcion registrada -> mail a admins/gerentes/deposito
create or replace function public.trg_recepcion_mail()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_oc_folio text;
  v_prov text;
  v_user record;
  v_user_name text;
begin
  select c.folio, p.razon into v_oc_folio, v_prov
  from compras c join proveedores p on p.id = c.proveedor_id
  where c.id = new.compra_id;

  for v_user in
    select u.id, u.email, u.full_name
    from profiles u
    where u.role in ('admin','gerencia','deposito') and u.active = true
  loop
    v_user_name := coalesce(v_user.full_name, split_part(v_user.email,'@',1));
    perform public.enqueue_email(
      v_user.email, v_user_name,
      'Recepción ' || new.folio || ' - OC ' || v_oc_folio,
      public.template_recepcion(new.folio, v_oc_folio, v_prov, new.conformidad, v_user_name),
      'recepcion',
      new.folio
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists tg_recep_mail on recepciones;
create trigger tg_recep_mail
  after insert on recepciones
  for each row execute function public.trg_recepcion_mail();

-- 2) Tarea asignada -> mail al asignado
create or replace function public.trg_tarea_mail()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_email text;
  v_user_name text;
  v_fecha text;
begin
  if new.asignado_id is not null and new.asignado_id != new.creador_id then
    select email, full_name into v_user_email, v_user_name
    from profiles where id = new.asignado_id;
    if v_user_email is not null then
      v_user_name := coalesce(v_user_name, split_part(v_user_email,'@',1));
      v_fecha := coalesce(to_char(new.fecha_limite, 'DD/MM/YYYY'), 'sin fecha');
      perform public.enqueue_email(
        v_user_email, v_user_name,
        'Nueva tarea: ' || new.titulo,
        public.template_tarea(new.titulo, v_user_name, v_fecha, 'asignada'),
        'tarea',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tg_tarea_mail on tareas;
create trigger tg_tarea_mail
  after insert on tareas
  for each row execute function public.trg_tarea_mail();

-- 3) Stock bajo minimo -> mail a admin/compras/deposito
create or replace function public.trg_stock_mail()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user record;
  v_user_name text;
  v_productos text;
  v_count int;
begin
  if (new.stock <= new.stock_min) and (old.stock is null or old.stock > old.stock_min) then
    select string_agg(sku || ' - ' || nombre || ' (stock: ' || stock || ', min: ' || stock_min || ')', E'\n'),
           count(*) into v_productos, v_count
    from productos
    where stock <= stock_min and active = true;
    if v_count > 0 then
      for v_user in
        select u.id, u.email, u.full_name
        from profiles u
        where u.role in ('admin','compras','deposito') and u.active = true
      loop
        v_user_name := coalesce(v_user.full_name, split_part(v_user.email,'@',1));
        perform public.enqueue_email(
          v_user.email, v_user_name,
          v_count || ' producto(s) bajo stock mínimo',
          public.template_stock_critico(v_productos, v_user_name),
          'stock',
          null
        );
      end loop;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tg_stock_mail on productos;
create trigger tg_stock_mail
  after update of stock on productos
  for each row execute function public.trg_stock_mail();

select 'Schema de notificaciones (public) listo. Siguiente: deployar Edge Function.' as status;
