-- SentiSalud · Esquema de base de datos (Supabase / PostgreSQL)
-- Ejecuta este script en Supabase → SQL Editor.
-- Después copia Project URL y anon key en index.html (SUPABASE_URL / SUPABASE_KEY).

-- ───────────────────────── Directorio de farmacias ─────────────────────────
create table if not exists sedes (
  id        text primary key,
  nombre    text,
  cadena    text,
  direccion text,
  ciudad    text,
  eps       text[],
  lat       double precision,
  lng       double precision
);

-- ───────────────────────── Reportes ciudadanos ─────────────────────────────
create table if not exists reports (
  id          bigint generated always as identity primary key,
  sede_id     text references sedes(id),
  estado      text check (estado in ('VERDE','AMARILLO','ROJO')),
  ciudad      text,
  user_id     uuid references auth.users,
  lat         double precision,
  lng         double precision,
  distancia_m integer,
  created_at  timestamptz default now()
);
create index if not exists idx_reports_sede on reports (sede_id, created_at desc);

-- ───────────────────────── Avisos (alertas) ────────────────────────────────
create table if not exists alerts (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users,
  med        text,
  ciudad     text,
  created_at timestamptz default now()
);

-- ───────────────────────── Ledger de SentiCoins ────────────────────────────
create table if not exists coins_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users,
  delta      integer,
  motivo     text,
  created_at timestamptz default now()
);

-- ───────── Stock derivado: estado más reciente por farmacia ─────────────────
create or replace view sede_stock as
select distinct on (sede_id)
       sede_id, estado, created_at
from reports
order by sede_id, created_at desc;

-- ───────────────────────── Seguridad (RLS) ─────────────────────────────────
alter table reports enable row level security;
alter table alerts  enable row level security;

-- Lectura pública de reportes (para mostrar el semáforo a todos)
create policy "leer reportes"  on reports for select using (true);
create policy "leer avisos"    on alerts  for select using (true);

-- IMPORTANTE: la app actual envía reportes/avisos ANÓNIMOS (sin user_id),
-- por eso el insert se permite abiertamente. Esto es suficiente para el MVP.
create policy "crear reportes" on reports for insert with check (true);
create policy "crear avisos"   on alerts  for insert with check (true);

-- PARA PRODUCCIÓN: cuando agregues autenticación (Supabase Auth), reemplaza las
-- dos políticas de insert anteriores por estas, que atan cada fila a su dueño:
--   create policy "crear mis reportes" on reports for insert with check (auth.uid() = user_id);
--   create policy "crear mis avisos"   on alerts  for insert with check (auth.uid() = user_id);
