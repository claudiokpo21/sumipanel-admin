# Prompt de rediseño — ECU·GLOBAL Landing

## Contexto del proyecto

`https://ecu-global-c1.vercel.app/` es una landing para un **simulador eléctrico interactivo de motos**. El usuario es mecánico / taller y la propuesta de valor es:

- Diagramas eléctricos vectoriales interactivos
- Asignación de pines y colores de cableado
- Diagnóstico con multímetro (6–9 tests por componente)
- Filtros por circuito (alimentación, encendido, sensores, actuadores, CAN/OBD)
- Acceso por registro con login Google o email/pass
- 3 modelos disponibles (KTM, Yamaha R1, Honda) — 113 pines, 38+ componentes, 200+ tests

Stack actual: **HTML + CSS + JS vanilla, un solo archivo**, desplegado en Vercel. Conviene mantener ese stack (sin React, sin build step, sin backend).

---

## Identidad de marca a respetar

- **Marca madre**: `ECU·GLOBAL` (o `ECU/GLOBAL`)
- **Línea de producto**: `MOTO` (el simulador específico de motos)
- **Tagline**: *Simulador Eléctrico Interactivo*
- **Tono**: técnico, de taller, profesional, sin exceso de marketing
- **Idioma**: español (rioplatense neutral)

### Paleta consolidada (limpiar la actual)

| Token | Valor | Uso |
|---|---|---|
| `--bg` | `#080a0f` | Fondo principal |
| `--panel` | `#0e1118` | Cards, modales |
| `--panel-2` | `#151922` | Sidebars, secciones |
| `--border` | `rgba(255,255,255,.07)` | Bordes sutiles |
| `--tx` | `#e2e4ee` | Texto principal |
| `--tx2` | `#8890aa` | Texto secundario (contraste AA ✓) |
| `--tx3` | `#454a66` | Solo decorativo (contraste <2:1, no usar para info) |
| `--cyan` | `#00c8f0` | **Acento principal** del sitio |
| `--orange` | `#ff6b35` | **EXCLUSIVO** para KTM (color de marca) |
| `--gold` | `#f5c430` | Warnings / precaución |
| `--red` | `#e24b4a` | Errores / crítico |
| `--green` | `#00d68a` | OK / medición correcta |
| ~~purple~~ | ~~`#a78bfa`~~ | **ELIMINAR** de features (queda inconsistente) |

### Tipografía (mantener)

```html
<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Space+Mono:wght@400;700&family=DM+Sans:ital,wght@0,300;0,400;0,500;1,300&display=swap" rel="stylesheet">
```

- `Bebas Neue` → títulos grandes, números, logos
- `Space Mono` → labels, badges, datos técnicos, código
- `DM Sans` → cuerpo de texto

---

## Estructura de la landing (de arriba a abajo)

```
1. Nav sticky
2. Hero (texto izq + mockup simulador der, en mobile apilado)
3. Stats animadas (counter)
4. Sección "Cómo se usa" (3-4 pasos numerados)
5. Features (grilla con 1 card destacada 2x1 + 4 cards normales)
6. Modelos disponibles (3 cards con silueta SVG de cada moto)
7. Sección diagnóstico (mockup con scan line + texto explicativo)
8. Mini-comparador de modelos (tabla simple)
9. Trust signals / prueba social
10. CTA final
11. Footer
```

---

## Mejoras prioritarias a implementar

### P0 — Impacto visual alto (obligatorias)

#### 1. Mockup del simulador en el hero
Renderizar una "ventana" de navegador falsa que muestre el producto en miniatura:

- Chrome de browser con 3 dots + URL bar (`https://ecu-global.app/simulador/ktm-950`)
- Sidebar izquierda con 6–8 componentes (icono + nombre + dot de status verde/rojo)
- Área central con un mini diagrama SVG (3–4 componentes conectados con cables de colores)
- Panel inferior con un multímetro falso mostrando `12.4V DC` con barras animadas
- Cursor falso (SVG con `position:absolute`) moviéndose lentamente sobre un componente
- Aplicar `transform: perspective(1400px) rotateY(-6deg) rotateX(2deg)` y un glow cyan detrás
- En mobile (<768px): apilar abajo del texto, sin rotate

#### 2. Siluetas SVG de las 3 motos en las cards
Cada `.model-card` debe tener una **silueta side-view** de la moto como elemento visual:

- **KTM** (naked adventure tipo Duke/Adventure): tanque anguloso, asiento alto, antena GPS
- **Yamaha R1** (sport carenada): carenado completo, doble escape bajo, alerón trasero
- **Honda** (naked tipo CB/CBR): tanque redondeado, escape lateral, faro redondo

SVG inline con `fill="currentColor"` o `fill="url(#gradient-{modelo})"`, opacidad `0.85`, posicionado absoluto cubriendo el 60% inferior de la card. Fondo de gradiente de la card (radial + linear) sigue funcionando como backdrop.

#### 3. Stats con counter animado
Las 4 stats del hero (3, 113, 38+, 200+) deben animar de 0 al target al entrar en viewport:

```js
function animateCounter(el) {
  const target = parseInt(el.dataset.target);
  const suffix = el.dataset.suffix || '';
  const duration = 1800;
  const start = performance.now();
  function step(now) {
    const t = Math.min((now - start) / duration, 1);
    const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
    el.textContent = Math.floor(eased * target) + suffix;
    if (t < 1) requestAnimationFrame(step);
    else el.textContent = target + suffix;
  }
  requestAnimationFrame(step);
}
```

Usar `IntersectionObserver` para disparar cuando `.stats-row` entra en viewport. Si el usuario tiene `prefers-reduced-motion`, saltar la animación y mostrar el target directo.

### P1 — Impacto medio (recomendadas)

#### 4. Brand unificado
- `nav-logo`: `ECU·GLOBAL` (con punto medio) + `<span>MOTO</span>` más chico al lado
- `<title>`: `ECU·GLOBAL · Simulador Eléctrico de Motos`
- OG title: `ECU·GLOBAL — Simulador eléctrico de motos`

#### 5. mc-pins visible
Subir opacidad de `0.06` a `0.20` o convertirlo en badge con border:
```css
.mc-pins {
  position: absolute; top: 20px; right: 20px;
  font-family: 'Bebas Neue', sans-serif; font-size: 14px;
  padding: 4px 10px;
  background: rgba(0, 200, 240, 0.1);
  border: 1px solid rgba(0, 200, 240, 0.3);
  border-radius: 3px;
  color: var(--cyan);
  letter-spacing: 0.1em;
}
```

#### 6. Paleta de features limpia
Reemplazar los `--accent` de las 6 cards:
- Card 1 (Diagramas): `--cyan`
- Card 2 (Corriente): `--gold`
- Card 3 (Diagnóstico): `--green`
- Card 4 (Pines y colores): `--cyan`
- Card 5 (Filtros): `--cyan`
- Card 6 (Acceso controlado): `--red` (privacidad es riesgo)

**Eliminar** el purple `#a78bfa`.

#### 7. Card destacada 2x1
La primera card de features ocupa `grid-column: span 2` con un visual/animación adentro (mini SVG de un circuito con componentes clickeables animados). Rompe el ritmo 3x2.

#### 8. Radial glow breathing
```css
.hero-glow { animation: breathe 6s ease-in-out infinite; }
@keyframes breathe {
  0%, 100% { transform: translateX(-50%) scale(1); opacity: 0.8; }
  50% { transform: translateX(-50%) scale(1.05); opacity: 1; }
}
```

#### 9. nav-tag vivo
Reemplazar `Simulador Eléctrico v1.0` por:
```html
<div class="nav-tag">
  <span class="live-dot"></span> ONLINE · 3 MODELOS
</div>
```
```css
.live-dot {
  display: inline-block; width: 6px; height: 6px;
  background: var(--green); border-radius: 50%;
  margin-right: 6px; vertical-align: middle;
  animation: pulse 1.5s ease-in-out infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(0, 214, 138, 0.5); }
  50% { opacity: 0.7; box-shadow: 0 0 0 4px rgba(0, 214, 138, 0); }
}
```

#### 10. Trust signals en CTA final
Antes del botón del CTA, agregar 3 mini badges en línea:
```html
<div class="trust-row">
  <span>● Actualizado mensualmente</span>
  <span>● +200 tests de multímetro</span>
  <span>● Sin instalación</span>
</div>
```

#### 11. Sección "Cómo se usa"
3–4 pasos numerados, layout horizontal en desktop, vertical en mobile:
```
01  Elegí modelo              →  KTM / R1 / Honda
02  Tocá un componente        →  ECU, sensor, actuador
03  Medí con multímetro       →  Voltaje, resistencia, continuidad
04  Diagnosticá la falla      →  Comparás con valores esperados
```

Cada paso: número grande en `Bebas Neue` cyan, título bold, descripción corta.

### P2 — Detalles (nice to have)

#### 12. Favicon + OG image inline
Favicon SVG inline (data URI) con el logo `ECU·GLOBAL` estilizado.
OG image: si no hay tiempo para hacer una imagen real, dejá un comment explicando que se necesita una imagen 1200x630px con screenshot del simulador.

#### 13. Fallback no-js para scroll-reveal
```html
<html lang="es" class="no-js">
<script>document.documentElement.classList.remove('no-js')</script>
```
```css
.no-js .reveal { opacity: 1; transform: none; }
```

#### 14. Noise overlay más sutil
Bajar `opacity: 0.4` a `0.2` para evitar textura molesta en retina.

#### 15. Detalles "de taller"
- En el fondo del hero, agregar 2–3 strings de jerga técnica rotadas `-15deg` con opacidad `0.04`:
  - `12V · 0.5A · OHM`
  - `CAN-BUS · JIS · OBD-II`
  - `KTM/HUSQVARNA · YAMAHA · HONDA`
- Multímetro SVG decorativo en algún borde de sección (puede ser un asset simple en blanco/cyan a opacidad `0.08`)

#### 16. Indicador de sección activa en nav
Al scrollear, resaltar el link correspondiente en una mini-nav de secciones (#modelos, #diagnostico, etc.). Si no hay links de ancla, agregar un TOC discreto al costado o arriba.

#### 17. Mini-comparador de modelos
Tabla simple 3 columnas (KTM / R1 / Honda) con 4–5 filas (año, sistema eléctrico, pines mapeados, tests, voltaje). Bordes finos, texto `Space Mono` para los valores, hover highlight cyan en la celda.

#### 18. Hamburger en mobile
Nav colapsa a burger drawer en <768px.

---

## Restricciones técnicas

- **Un solo archivo HTML** (todo inline: CSS, JS, SVGs)
- **Sin dependencias externas** más allá de Google Fonts
- **Responsive**: mobile-first, breakpoints en 480, 768, 1024
- **Performance**: total <300KB (sin imágenes externas; todo SVG o CSS)
- **Accesibilidad**: respetar `prefers-reduced-motion`, alt text en SVGs semánticos, contraste AA en texto informativo
- **SEO**: meta description, og:image, structured data básico (Organization + SoftwareApplication)
- **No usar** `tailwind` ni `bootstrap` ni `react` ni `vite`

---

## Criterios de aceptación

1. ✅ El hero muestra el mockup del simulador visible y animado (sin rotate en mobile)
2. ✅ Las 3 cards de modelos tienen siluetas SVG reconocibles de cada moto
3. ✅ Las 4 stats del hero animan desde 0 al entrar en viewport (y respetan reduced-motion)
4. ✅ El logo es `ECU·GLOBAL` consistente en nav, title, og
5. ✅ La paleta de features no incluye purple
6. ✅ El CTA final tiene trust signals antes del botón
7. ✅ Existe una sección "Cómo se usa" con 3-4 pasos
8. ✅ El sitio funciona con JS deshabilitado (no secciones invisibles)
9. ✅ Lighthouse Performance >90, Accessibility >90
10. ✅ El sitio se ve bien a 360px, 768px, 1280px, 1920px

---

## Entregable

Un único archivo `index.html` que reemplace al actual. Mantener el archivo actual como backup (`index.v1.html.backup`). Después de deployar, validar en:
- Mobile: `npx serve .` y abrir en DevTools modo responsive
- Desktop: `http://localhost:3000`
- Compartir en WhatsApp y verificar preview de OG image

---

## Notas adicionales para el modelo

- No agregues secciones que no estén en esta lista. Si querés proponer más, mencionalo aparte.
- Priorizá impacto visual sobre features nuevas. Es una landing, no una app.
- Si el hero mockup del simulador es muy complejo, podés simplificarlo: una ventana con un solo componente (la ECU) clickeado mostrando un panel lateral con specs. Menos es más.
- Las siluetas de las motos no necesitan ser perfectas. Side-view simplificado con 6–10 paths cada una es suficiente.
- El usuario prefiere respuestas en español rioplatense, tono directo y código comentado.
