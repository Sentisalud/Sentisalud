# SentiSalud — Especificación técnica

Versión del documento: 1.0 · Junio de 2026
Estado de la app: prototipo funcional de alta fidelidad con funciones reales en frontend.

---

## 1. Resumen

SentiSalud es una PWA de una sola página (vanilla JS) para localizar
medicamentos disponibles mediante reportes ciudadanos y para generar acciones de
tutela. No tiene paso de compilación ni dependencias instaladas; toda la lógica
vive en `index.html`. Los datos de farmacias están embebidos y, opcionalmente,
se sobreescriben desde `farmacias.json`. La persistencia es local
(`localStorage`) y existe una capa lista para conectar un backend real
(Supabase) sin reescribir la app.

## 2. Arquitectura

```
┌──────────────────────────────────────────────────────────┐
│                       index.html                          │
│  UI (HTML+CSS)                                            │
│  ──────────────────────────────────────────────────────  │
│  Vistas: Radar · Avisos · Tutela · Mi cuenta             │
│  Lógica JS                                                │
│   ├─ Mapa (Leaflet + tiles CARTO)                         │
│   ├─ GPS antifraude (Haversine, umbral 300 m)             │
│   ├─ Persistencia local (LS sobre localStorage)           │
│   ├─ Firma SHA-256 (crypto.subtle)                        │
│   ├─ Catálogo de medicamentos (API datos.gov.co)          │
│   └─ Cloud (Supabase, opcional, escritura)                │
└───────────────┬──────────────────────────┬───────────────┘
                │                          │
        farmacias.json            Servicios externos
        (directorio editable)     · Leaflet CDN
                                  · CARTO basemaps
                                  · datos.gov.co (Socrata)
                                  · Supabase (opcional)
        Service Worker  ── cache offline del app shell
```

### 2.1 Stack

| Capa        | Tecnología                                             |
|-------------|--------------------------------------------------------|
| Lenguaje    | HTML5, CSS3, JavaScript ES5/ES6 (sin transpilar)       |
| Mapa        | Leaflet 1.9.4 (CDN cdnjs)                               |
| Tiles       | CARTO `light_all` (OpenStreetMap)                      |
| Tipografía  | Plus Jakarta Sans (Google Fonts)                       |
| PWA         | Web App Manifest + Service Worker                      |
| Persistencia| `localStorage` (clave `ss_*`)                          |
| Cripto      | Web Crypto API (`crypto.subtle.digest` SHA-256)        |
| Backend opc.| Supabase (PostgreSQL + REST + Auth)                    |

### 2.2 Requisitos de ejecución

Geolocalización, `crypto.subtle` y el service worker requieren **contexto
seguro** (`https://` o `localhost`). Bajo `file://` la app degrada con elegancia:
`loadExternal()` se salta el fetch y la firma cae a un hash de respaldo.

## 3. Modelo de datos

### 3.1 Farmacia (objeto `sede`)

| Campo  | Tipo      | Descripción                                   |
|--------|-----------|-----------------------------------------------|
| `id`   | string    | Identificador único (p. ej. `"SU01"`)         |
| `n`    | string    | Nombre de la sede                             |
| `ch`   | string    | Cadena/operador (clave de `FUENTES`)          |
| `addr` | string    | Dirección                                     |
| `city` | string    | Ciudad (debe existir en `CITIES`)             |
| `eps`  | string[]  | EPS atendidas (no vacío)                       |
| `est`  | enum      | `VERDE` \| `AMARILLO` \| `ROJO`               |
| `fila` | number    | Fila estimada en horas (0.5 = 30 min)         |
| `lat`  | number    | Latitud                                       |
| `lng`  | number    | Longitud                                      |

Validado: 323 registros, IDs únicos, sin campos faltantes, estados válidos,
coordenadas dentro de Colombia, EPS no vacías.

### 3.2 Cobertura actual

| Ciudad        | Farmacias |
|---------------|----------:|
| Bogotá        | 73        |
| Cali          | 62        |
| Medellín      | 55        |
| Barranquilla  | 50        |
| Cartagena     | 42        |
| Bucaramanga   | 12        |
| Cúcuta        | 11        |
| Pereira       | 10        |
| Popayán       | 8         |
| **Total**     | **323**   |

Distribución de estado: 186 VERDE · 101 AMARILLO · 36 ROJO.

> Nota de consistencia: los documentos de proyecto mencionan 313 farmacias y la
> base actual tiene 323. Conviene unificar el dato en informe, pitch y manual.

### 3.3 Estructuras auxiliares

- `CITIES` — lista de 9 ciudades.
- `CENTER` — centro [lat,lng] de cada ciudad para el mapa.
- `JUZGADOS` — correo del juzgado de reparto por ciudad (tutela).
- `FUENTES` — URL oficial por operador.
- `MEDS`, `EPS_LIST` — catálogos internos de respaldo.

Las tres listas dependientes de ciudad (`CITIES`, `CENTER`, `JUZGADOS`) están
verificadas como completas para las 9 ciudades.

## 4. Persistencia local

Capa mínima `LS` con prefijo `ss_`:

| Clave         | Contenido                              |
|---------------|----------------------------------------|
| `ss_coins`    | SentiCoins del usuario                 |
| `ss_alerts`   | Avisos creados                         |
| `ss_reports`  | `{ id_sede: { est, fila, ts } }`       |
| `ss_geo`      | Geocodificación afinada por sede       |
| `ss_easy`     | Modo fácil activado                    |

Al iniciar, `loadState()` recupera estado y `applyReports()`/`applyGeo()` lo
proyectan sobre `SEDES` antes del primer render.

## 5. Seguridad y antifraude

- **Verificación de ubicación:** `navigator.geolocation.getCurrentPosition` +
  `haversine()`. Un reporte solo se acepta si la distancia a la sede es ≤
  `GEO_THRESHOLD` (300 m, ajustable).
- **Firma del documento de tutela:** `sha256Hex()` usa
  `crypto.subtle.digest('SHA-256', …)`. Si el entorno no es seguro, cae a
  `simpleHash` (respaldo no criptográfico, claramente identificado en código).
- **Privacidad:** no se recopilan datos personales en servidores propios
  mientras Supabase esté desactivado; todo vive en el dispositivo.

## 6. Integración con datos.gov.co

- Endpoint Socrata: `https://www.datos.gov.co/resource/{dataset}.json?$q={texto}&$limit=8`
- Dataset por defecto: `CUM_DATASET = "i7cb-raxc"` (Código Único de Medicamentos Vigentes).
- `pickMedName()` elige el campo de nombre más probable y `wireMedAutocomplete()`
  alimenta el `<datalist id="medlist">` con un *debounce* de 300 ms.
- **Respaldo:** si la API no responde o no devuelve filas, se filtra la lista
  interna `MEDS`, de modo que el autocompletado nunca queda vacío.

> **Pendiente de verificación:** el `dataset id` y los nombres de campo no se
> pudieron probar en vivo durante la preparación del repositorio. Confirma en la
> pestaña Red del navegador que el endpoint responde y, si hace falta, ajusta
> `CUM_DATASET` o el orden de campos en `pickMedName()`.

## 7. Backend opcional (Supabase)

Mientras `SUPABASE_URL`/`SUPABASE_KEY` estén vacíos, la app es 100% local. Al
configurarlas, la capa `Cloud` envía cada evento por REST:

| Acción        | Tabla     | Disparador        |
|---------------|-----------|-------------------|
| Reporte stock | `reports` | `sendReport()`    |
| Crear aviso   | `alerts`  | `addAlert()`      |

El envío es *fire-and-forget*: si la red falla, el dato igual queda en local. El
esquema y las políticas RLS están en `docs/supabase_schema.sql`. El stock real
compartido se deriva de la tabla `reports` (vista `sede_stock`: estado más
reciente por sede).

## 8. PWA

- `manifest.webmanifest`: `display: standalone`, `theme_color #0F2044`,
  `background_color #EEF3FD`, íconos 32/180/192/512 + maskable.
- `service-worker.js`: cache-first del app shell, network-first para
  `farmacias.json`, y **no intercepta orígenes externos** (CDN, tiles, APIs).
  Versionado por `VERSION`; subir la versión fuerza actualización.

## 9. Limitaciones conocidas

1. **No hay inventario en tiempo real** de farmacias como fuente pública en
   Colombia. El stock es comunitario (reportes), no un feed oficial.
2. Sin Supabase, los reportes son **locales por dispositivo**, no compartidos.
3. Las **notificaciones push** de los avisos aún no están implementadas
   (requieren backend + Web Push).
4. No hay **autenticación** de usuarios todavía.

## 10. Roadmap técnico sugerido

1. Lectura compartida del stock desde Supabase (volver asíncrona la carga
   inicial y leer la vista `sede_stock`).
2. Autenticación (Supabase Auth) y ledger real de SentiCoins.
3. Notificaciones push de avisos (Supabase Edge Functions + Web Push).
4. Geocodificación oficial de farmacias desde el dataset de establecimientos
   autorizados de datos.gov.co.
5. Capa de moderación/consenso para reportes (evitar manipulación).
