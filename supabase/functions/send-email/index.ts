// Edge Function: send-email
// Lee la cola notif_queue y manda cada mail via Resend
// Se invoca con un GET o POST (con autenticacion anon del proyecto)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'SUMIPANEL <noreply@sumipanel.com.ar>';
const MAX_PER_RUN = 20;

const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

Deno.serve(async (req) => {
  // Solo permitir con token secreto (header 'x-cron-key') o desde el mismo proyecto
  const cronKey = req.headers.get('x-cron-key');
  const expectedKey = Deno.env.get('CRON_SECRET') || 'sumipanel-cron-2026';
  if (cronKey !== expectedKey) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    // 1) Traer pendientes
    const { data: emails, error } = await db
      .from('notif_queue')
      .select('*')
      .eq('estado', 'pendiente')
      .lt('intentos', 3)
      .order('created_at', { ascending: true })
      .limit(MAX_PER_RUN);

    if (error) throw error;
    if (!emails || emails.length === 0) {
      return new Response(JSON.stringify({ sent: 0, msg: 'cola vacia' }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    let sent = 0, failed = 0;
    for (const e of emails) {
      try {
        const r = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: FROM_EMAIL,
            to: [e.to_email],
            subject: e.subject,
            html: e.html_body,
          }),
        });
        if (r.ok) {
          await db.from('notif_queue').update({
            estado: 'enviado',
            sent_at: new Date().toISOString(),
            intentos: (e.intentos || 0) + 1
          }).eq('id', e.id);
          sent++;
        } else {
          const txt = await r.text();
          await db.from('notif_queue').update({
            intentos: (e.intentos || 0) + 1,
            ultimo_error: txt.slice(0, 500)
          }).eq('id', e.id);
          failed++;
        }
      } catch (err) {
        await db.from('notif_queue').update({
          intentos: (e.intentos || 0) + 1,
          ultimo_error: String(err).slice(0, 500)
        }).eq('id', e.id);
        failed++;
      }
    }

    return new Response(JSON.stringify({ sent, failed, total: emails.length }), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});
