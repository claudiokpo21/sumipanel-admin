// ============================================
// Kimey · lógica de selección + WhatsApp
// ============================================

// ⚠️ Cambiá este número por el real de Kimey (con código de país, sin + ni espacios)
const WSP_NUMBER = "5491100000000";

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const checks = $$(".svc");
const cards  = $$(".card");
const list   = $("#q-list");
const count  = $("#q-count");
const btnWsp = $("#btn-wsp");
const btnClear = $("#btn-clear");
const msg    = $("#q-msg");
const ctaWsp = $("#cta-wsp");

const inputName  = $("#q-name");
const inputDate  = $("#q-date");
const inputNotes = $("#q-notes");

// Año en footer
$("#year").textContent = new Date().getFullYear();

// ---- Sync UI ----
function getSelected(){
  return Array.from(checks).filter(c => c.checked).map(c => c.value);
}

function render(){
  const sel = getSelected();
  count.textContent = sel.length;
  list.innerHTML = sel.length
    ? sel.map(s => `<li>${s}</li>`).join("")
    : `<li style="opacity:.6">Ninguno todavía — tildá al menos uno ↑</li>`;

  cards.forEach(card => {
    const cb = card.querySelector(".svc");
    card.classList.toggle("is-picked", cb.checked);
  });

  // CTA grande del final: si hay selección, pre-rellena el mensaje
  if (ctaWsp) ctaWsp.href = buildWspLink(sel, { prefill: true });
}

checks.forEach(c => c.addEventListener("change", render));
[inputName, inputDate, inputNotes].forEach(el =>
  el && el.addEventListener("input", render)
);

// ---- Build WhatsApp link ----
function buildWspLink(sel, opts = {}){
  const name  = (inputName?.value  || "").trim();
  const date  = (inputDate?.value  || "").trim();
  const notes = (inputNotes?.value || "").trim();

  if (sel.length === 0 && !opts.force){
    return `https://wa.me/${WSP_NUMBER}?text=${encodeURIComponent(
      "Hola Kimey! Quiero consultar por sus servicios."
    )}`;
  }

  const lines = [];
  lines.push("Hola Kimey! Quiero cotizar los siguientes servicios: 👇");
  lines.push("");

  if (sel.length){
    lines.push("• " + sel.join("\n• "));
  } else {
    lines.push("(Sin servicios seleccionados por ahora, quiero más info)");
  }
  lines.push("");

  if (name)  lines.push(`Nombre: ${name}`);
  if (date)  lines.push(`Fecha del evento: ${formatDate(date)}`);
  if (notes) {
    lines.push("");
    lines.push(`Notas / referencias:\n${notes}`);
  }
  lines.push("");
  lines.push("Quedo atenta, gracias! 💚");

  return `https://wa.me/${WSP_NUMBER}?text=${encodeURIComponent(lines.join("\n"))}`;
}

function formatDate(iso){
  // iso = YYYY-MM-DD
  if (!iso || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) return iso;
  const [y,m,d] = iso.split("-");
  return `${d}/${m}/${y}`;
}

// ---- Botón principal: enviar ----
btnWsp.addEventListener("click", () => {
  const sel = getSelected();
  if (sel.length === 0 && !confirm("No seleccionaste ningún servicio. ¿Querés igual abrir WhatsApp para consultar?")){
    return;
  }
  msg.textContent = "Abriendo WhatsApp...";
  msg.classList.add("is-ok");
  const link = buildWspLink(sel, { force: true });
  window.open(link, "_blank", "noopener");
  setTimeout(() => { msg.textContent = ""; msg.classList.remove("is-ok"); }, 3000);
});

// ---- Limpiar selección ----
btnClear.addEventListener("click", () => {
  checks.forEach(c => c.checked = false);
  if (inputName)  inputName.value  = "";
  if (inputDate)  inputDate.value  = "";
  if (inputNotes) inputNotes.value = "";
  render();
  msg.textContent = "Selección limpiada ✓";
  msg.classList.add("is-ok");
  setTimeout(() => { msg.textContent = ""; msg.classList.remove("is-ok"); }, 2000);
});

// Init
render();
