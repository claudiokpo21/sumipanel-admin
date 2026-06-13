# Diagnóstico troublesheet.html — 2026-06-09

## ✅ Lo que FUNCIONA (no tocar)

| Página / Feature | Estado | Evidencia |
|---|---|---|
| Página carga sin errores JS | ✅ OK | Único error consola: 404 favicon.ico (espurio) |
| Home page | ✅ OK | Render correcto, h1, hero, stats |
| Navegación lateral (10 secciones) | ✅ OK | Click activa la página, remueve active de las otras |
| Modelo OSI (7 capas) | ✅ OK | Click expande/colapsa el detail |
| TCP/IP, VLAN, Cheatsheet, Telecom | ✅ OK | Renderizan con contenido |
| Calculadora IPv4/VLSM/IPv6 | ✅ OK | 3 tabs funcionales, cálculo `10.0.0.130/25` → resultado correcto |
| Copy buttons de comandos | ✅ OK | Feedback "copy" → "copied" 2s, clase `copied` aplicada |
| Wizard de troubleshooting | ✅ OK | `wizardTree` carga, renderWizard() popula "Paso 1 de ~7" |

## 🐛 BUGS REALES (2, ambos en la misma causa raíz)

### BUG 1 — "Casos Reales (23)" muestra pantalla vacía
- **Síntoma**: Click en nav → solo se ve el header + filter bar (Todos, Capa 1, Capa 2, L3, L4, Aplicación, Avanzado, Telecom). Debajo: nada.
- **Causa**: `<div id="casosList"></div>` (línea 474) está **vacío en el HTML** y **no existe ningún JS que lo popule**.
- **Prometido**: 23 escenarios. **Entregado**: 0.

### BUG 2 — "Quiz / Examen" muestra pantalla vacía
- **Síntoma**: Click en nav → solo se ven las stats tiles (Respondidas 0/50, Correctas 0, Score 0%). Debajo: nada.
- **Causa**: `<div id="quizContainer"></div>` (línea 491) está **vacío en el HTML** y **no existe ningún JS que lo popule**.
- **Prometido**: 50 preguntas CCNA+CCNP. **Entregado**: 0.

## 🔎 Causa raíz

El archivo tiene **un solo `<script>` inline** (línea 901, sin scripts externos, sin fetch a JSON).
Los arrays de datos necesarios **no existen en ningún lugar del archivo**:
- `typeof window.quizData` → `undefined`
- `typeof window.casosData` → `undefined`
- `typeof window.wizardData` → `undefined`
- Grep por `casosList|quizContainer|renderQuiz|renderCasos|loadCasos|loadQuiz` → solo aparecen como **IDs vacíos en HTML**, ninguna función los referencia.

CSS para `.quiz-card`, `.quiz-q`, `.quiz-opt`, `.quiz-explain` (líneas 121-130) está **listo y completo**, esperando data que nunca llega.

## 🎯 Lo que NO era el problema

- ❌ El warning `Unsafe attempt to load URL file:///...` que veías en la consola de Edge es un **falso positivo** del navegador con `file://`. Cargando vía `http://localhost:8000` desaparece. No afecta funcionalidad.
- ❌ El error `404 favicon.ico` es cosmético, no rompe nada.
- ❌ El `troublesheet.html` no está "roto" en general — **8 de 10 páginas funcionan perfecto**.

## 🛠 Cómo lo arreglo (opciones)

**Opción A — Preguntarte a vos qué pasó con esos datos** (recomendada)
Es muy raro que un archivo que promete 23 casos y 50 preguntas no tenga los datos. Posibilidades:
1. Se borraron por accidente en una edición anterior
2. Estaban en otro archivo que nunca se linkeó
3. Nunca se implementaron (es un stub)

Si tenés backup, git history, o el archivo viejo, los restauro. Si no, los genero yo desde cero (50 preguntas CCNA/CCNP y 23 escenarios).

**Opción B — Implementar todo desde cero**
Te armo las 50 preguntas del quiz (con explicaciones) y los 23 casos con topología/síntoma/diagnóstico/solución. Es ~1500-2000 líneas de JS adicionales. Lo dejo en 1-2 horas de trabajo.

**Opción C — Versión mínima funcional**
10 preguntas y 5-6 casos representativos (1 por capa + avanzado + telecom). Más rápido, cubre el flujo.

## 📂 Archivos del proyecto
- `C:\Users\Claudiop\Documents\CV Automatizacion\troublesheet.html` (94KB, 1320 líneas)
- Server actual: `python -m http.server 8000` en PID 20400, `http://127.0.0.1:8000/troublesheet.html`

## 🖼 Screenshots
- `C:\Users\Claudiop\troublesheet-home.png` (estado limpio, Home funcionando)
