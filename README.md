# SentiSalud — Radar de Medicamentos

Aplicación web progresiva (PWA) que ayuda a las personas a encontrar dónde hay
disponible su medicamento cerca de ellas, a partir de **reportes ciudadanos
verificados por GPS**, y a generar una **acción de tutela** sin abogado cuando
les niegan la entrega.

No requiere build, framework ni dependencias instaladas: es HTML + CSS + JS
vanilla en un solo archivo, más los archivos de la PWA.

---

## 1. Estructura del repositorio

```
sentisalud/
├── index.html              App completa (UI + lógica + datos embebidos)
├── manifest.webmanifest    Manifiesto PWA (instalable)
├── service-worker.js       Cache offline del app shell
├── farmacias.json          Directorio editable (323 farmacias, 9 ciudades)
├── icons/                  Íconos PWA (32 / 180 / 192 / 512 / maskable)
├── docs/
│   ├── ESPECIFICACION_TECNICA.md
│   └── supabase_schema.sql Esquema SQL para el backend opcional
├── README.md
├── LICENSE
└── .gitignore
```

## 2. Ejecutar en local

La app usa geolocalización, `crypto.subtle` (firma SHA-256) y un service worker.
Las tres **solo funcionan en contexto seguro**: `https://` o `localhost`.
Abrir el `index.html` con doble clic (`file://`) deshabilita esas funciones.

Levanta un servidor local:

```bash
# Python 3
python3 -m http.server 8080
# o Node
npx serve .
```

Luego abre `http://localhost:8080`.

## 3. Desplegar

Cualquier hosting estático con HTTPS sirve: GitHub Pages, Netlify, Vercel,
Cloudflare Pages. No hay paso de compilación; se publica la carpeta tal cual.

> Si despliegas en un subdirectorio (p. ej. GitHub Pages en
> `usuario.github.io/sentisalud/`), las rutas relativas (`./`) ya están
> preparadas para eso.

## 4. Datos de farmacias

- El `index.html` trae **323 farmacias embebidas** (funciona sin red).
- Al cargar, `loadExternal()` intenta leer `farmacias.json`; si existe, lo usa
  como fuente y muestra la fecha de actualización. Así puedes actualizar el
  directorio **sin tocar el HTML**.
- Ambos archivos están sincronizados hoy. Si editas uno, recuerda el otro.

Estructura de `farmacias.json`:

```json
{
  "meta":   { "actualizado": "2026-06-23", "total": 323 },
  "fuentes":{ "Cruz Verde": "https://...", "...": "..." },
  "sedes":  [ { "id":"...", "n":"...", "ch":"...", "addr":"...",
               "city":"...", "eps":["..."], "est":"VERDE",
               "fila":0.5, "lat":3.46, "lng":-76.53 } ]
}
```

`est` solo admite: `VERDE` (disponible), `AMARILLO` (poco), `ROJO` (agotado).

## 5. Funciones reales ya integradas

- **GPS antifraude:** geolocalización real del navegador + distancia Haversine.
  Solo deja reportar dentro de `GEO_THRESHOLD` (300 m).
- **Persistencia local:** capa `LS` sobre `localStorage` (SentiCoins, avisos,
  reportes y modo fácil sobreviven al recargar).
- **Firma SHA-256 real:** la tutela se firma con `crypto.subtle.digest`.
- **Catálogo real de medicamentos:** autocompletado en vivo desde la API de
  datos.gov.co (Código Único de Medicamentos Vigentes), con respaldo a la lista
  interna si la API no responde. Ver nota en la especificación técnica.

## 6. Activar el backend real (Supabase) — opcional

Mientras no configures Supabase, todo funciona en local. Para activarlo:

1. Crea un proyecto gratuito en [supabase.com](https://supabase.com).
2. En **SQL Editor**, ejecuta `docs/supabase_schema.sql`.
3. En **Settings → API**, copia *Project URL* y *anon public key*.
4. Pégalas en `index.html`:

   ```js
   var SUPABASE_URL = "https://xxxx.supabase.co";
   var SUPABASE_KEY = "tu_anon_key";
   ```

A partir de ahí, **cada reporte y aviso se escribe también en tu base de datos**
(envío silencioso; si falla la red, el dato igual queda en local). La lectura
compartida del stock entre usuarios es el siguiente paso (ver roadmap en la
especificación).

## 7. Límite importante y honesto

El semáforo de stock **no proviene de un inventario en tiempo real** de las
farmacias —ese dato no existe como fuente pública en Colombia—. Proviene de los
**reportes de la comunidad**. Confirma siempre con tu EPS antes de desplazarte.

---

SentiSalud · Documento de proyecto · Junio de 2026
