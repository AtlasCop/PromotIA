-- ============================================================================
-- Promot IA — Esquema de base de datos (Supabase / Postgres)
-- ============================================================================
-- Corresponde a docs/ARQUITECTURA.md (secciones 5-14) y
-- docs/MOTOR-INTELIGENCIA-DEMANDA.md (Capas 1-4).
--
-- Orden de ejecución: 1) este archivo  2) rls.sql  3) seed.sql
-- Pensado para correr UNA VEZ sobre un proyecto de Supabase nuevo (no es
-- idempotente a propósito, para mantener el SQL simple de leer).
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Tipos (enums)
-- ----------------------------------------------------------------------------

-- Tipo de cuenta (distinto del rol por ID): una cuenta "empresa" puede publicar
-- necesidades (demandante) y también buscar oportunidades (oferente); una
-- cuenta "proveedor" solo puede ser oferente. Confirmado en el chat del login.
create type tipo_cuenta_enum as enum ('empresa', 'proveedor');

-- Quién publica una necesidad puntual (ARQUITECTURA.md §5, MID Capa 1)
create type tipo_cliente_enum as enum ('persona', 'empresa', 'entidad');

create type urgencia_enum as enum ('baja', 'media', 'alta');

-- Workflow operativo de una ID (ARQUITECTURA.md §5)
create type estado_necesidad_enum as enum
  ('publicada', 'desbloqueada', 'en_conversacion', 'cerrada', 'perdida', 'cancelada');

-- Demanda Verificada — nivel de confianza, distinto del estado (ARQUITECTURA.md §9)
create type nivel_confianza_enum as enum
  ('publicada', 'verificada', 'activa', 'adjudicado');

create type tipo_archivo_enum as enum ('pdf', 'plano', 'foto', 'video');

create type tamano_empresa_enum as enum ('1-10', '11-50', '51-200', '200+');

create type plan_nombre_enum as enum ('bronce', 'plata', 'oro');

create type ciclo_facturacion_enum as enum ('mensual', 'anual');

create type estado_suscripcion_enum as enum ('trial', 'activa', 'cancelada', 'vencida');

create type estado_llamada_enum as enum ('programada', 'completada', 'cancelada');

create type metrica_tendencia_enum as enum
  ('conteo_necesidades', 'presupuesto_promedio', 'oferentes_activos');

create type tipo_insight_enum as enum ('creciente', 'decreciente', 'escasez_oferta');


-- ============================================================================
-- Identidad — una fila por cuenta autenticada (Supabase Auth)
-- ============================================================================

create table perfiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  tipo_cuenta   tipo_cuenta_enum not null,
  nombre        text not null,
  correo        text not null,
  telefono      text,
  creado_en     timestamptz not null default now()
);
comment on table perfiles is 'Identidad base de cada cuenta (empresa/proveedor). 1:1 con auth.users.';

-- Datos que hoy captura el paso 1 del wizard de registro.html para Demandante.
-- Solo tiene sentido para cuentas tipo_cuenta = 'empresa' (se valida por RLS/trigger).
create table perfiles_demandante (
  perfil_id         uuid primary key references perfiles (id) on delete cascade,
  tipo_cliente      tipo_cliente_enum not null default 'persona',
  ciudad            text,
  sector_economico  text,
  creado_en         timestamptz not null default now()
);
comment on table perfiles_demandante is 'Extensión de perfiles cuando la cuenta actúa como demandante (solo cuentas "empresa").';


-- ============================================================================
-- Capa 1 (MID) — Captura de datos
-- ============================================================================

create table industrias (
  id        uuid primary key default gen_random_uuid(),
  nombre    text not null,
  padre_id  uuid references industrias (id)
);
comment on table industrias is 'Taxonomía jerárquica (industria → subindustria). Arranca con Ingeniería + Construcción.';

create table necesidades (
  id                    uuid primary key default gen_random_uuid(),
  demandante_id         uuid not null references perfiles (id),
  titulo                text not null,
  -- Las 3 preguntas guiadas del wizard de publicar.html, como columnas separadas
  -- (más fiel a lo ya construido en publicar.html que un solo campo "descripcion").
  descripcion_necesita  text,
  descripcion_problema  text,
  descripcion_resultado text,
  industria_id          uuid references industrias (id),
  subindustria_id       uuid references industrias (id),
  pais                  text not null default 'Colombia',
  ciudad                text not null,
  presupuesto_min       numeric(14, 2),
  presupuesto_max       numeric(14, 2),
  fecha_requerida       date,
  urgencia              urgencia_enum not null default 'media',
  tipo_servicio         text,
  palabras_clave        text[] not null default '{}',
  -- Formaliza quién publica ESTA necesidad puntual (puede repetirse/diferir del
  -- tipo_cliente por defecto en perfiles_demandante — ver MID Capa 1).
  tipo_cliente          tipo_cliente_enum not null default 'persona',
  estado                estado_necesidad_enum not null default 'publicada',
  nivel_confianza       nivel_confianza_enum not null default 'publicada',
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now(),
  check (presupuesto_max is null or presupuesto_min is null or presupuesto_max >= presupuesto_min)
);
comment on table necesidades is 'La Intención de Demanda (ID). Teaser público: título/industria/ciudad/presupuesto/urgencia/descripción/fecha.';

-- Búsqueda de texto completo sobre título + las 3 preguntas guiadas.
alter table necesidades add column busqueda tsvector
  generated always as (
    to_tsvector('spanish',
      coalesce(titulo, '') || ' ' ||
      coalesce(descripcion_necesita, '') || ' ' ||
      coalesce(descripcion_problema, '') || ' ' ||
      coalesce(descripcion_resultado, '')
    )
  ) stored;

create index idx_necesidades_industria_ciudad on necesidades (industria_id, ciudad);
create index idx_necesidades_demandante on necesidades (demandante_id);
create index idx_necesidades_busqueda on necesidades using gin (busqueda);
create index idx_necesidades_creado_en on necesidades (creado_en);

create table necesidad_adjuntos (
  id            uuid primary key default gen_random_uuid(),
  necesidad_id  uuid not null references necesidades (id) on delete cascade,
  archivo_url   text not null,          -- privado — RLS hasta el desbloqueo
  miniatura_url text,                   -- público (el "gancho")
  tipo_archivo  tipo_archivo_enum not null,
  creado_en     timestamptz not null default now()
);
comment on table necesidad_adjuntos is 'archivo_url es el original (post-desbloqueo); miniatura_url es siempre pública.';

create index idx_adjuntos_necesidad on necesidad_adjuntos (necesidad_id);


-- ============================================================================
-- Capa 2 (MID) — Perfil de las empresas oferentes
-- ============================================================================

create table perfiles_oferente (
  oferente_id                     uuid primary key references perfiles (id) on delete cascade,
  nombre_empresa                  text,
  nit                             text,
  verificado                      boolean not null default false,
  verificado_en                   timestamptz,
  especialidades                  uuid[] not null default '{}',   -- industria_id[]
  ciudades_operacion              text[] not null default '{}',
  tamano_empresa                  tamano_empresa_enum,
  certificaciones                 text[] not null default '{}',
  sectores_atendidos              text[] not null default '{}',
  tecnologias_dominadas           text[] not null default '{}',
  rango_proyecto_min              numeric(14, 2),
  rango_proyecto_max              numeric(14, 2),
  experiencia_anios               integer,
  correo_contacto                 text,
  sitio_web                       text,
  portafolio_url                  text,
  -- Calculados a partir de mensajes/calificaciones — ver funciones más abajo.
  tiempo_respuesta_promedio_horas numeric(8, 2),
  nivel_satisfaccion              numeric(2, 1),
  credito_bienvenida_usado        boolean not null default false,
  fecha_registro                  timestamptz not null default now()
);
comment on table perfiles_oferente is 'Insumo directo del IAC (ARQUITECTURA.md §6). Perfil semi-público (reputación).';

create index idx_perfiles_oferente_especialidades on perfiles_oferente using gin (especialidades);
create index idx_perfiles_oferente_ciudades on perfiles_oferente using gin (ciudades_operacion);


-- ============================================================================
-- Créditos, planes y desbloqueo
-- ============================================================================

create table planes (
  id                    uuid primary key default gen_random_uuid(),
  nombre                plan_nombre_enum not null unique,
  creditos_mensuales    integer,             -- null = ilimitado
  ilimitado             boolean not null default false,
  precio_mensual_usd    numeric(10, 2) not null,
  descuento_anual_pct   numeric(4, 2) not null default 10,
  creado_en             timestamptz not null default now()
);
comment on table planes is 'Bronce/Plata/Oro — ver seed.sql para los valores confirmados en ARQUITECTURA.md §10.';

create table suscripciones (
  id                     uuid primary key default gen_random_uuid(),
  oferente_id            uuid not null references perfiles (id),
  plan_id                uuid not null references planes (id),
  ciclo_facturacion      ciclo_facturacion_enum not null default 'mensual',
  estado                 estado_suscripcion_enum not null default 'trial',
  creditos_disponibles   integer,            -- null cuando el plan es ilimitado
  fecha_inicio           timestamptz not null default now(),
  fecha_renovacion       timestamptz,
  stripe_subscription_id text,               -- para reconciliar con el webhook de Stripe
  creado_en              timestamptz not null default now()
);
comment on table suscripciones is 'Los créditos solo deben cambiar vía la función desbloquear_necesidad() o el webhook de Stripe (service_role) — nunca desde el cliente.';

create index idx_suscripciones_oferente on suscripciones (oferente_id);

create table desbloqueos (
  id                uuid primary key default gen_random_uuid(),
  necesidad_id      uuid not null references necesidades (id),
  oferente_id       uuid not null references perfiles (id),
  credito_consumido boolean not null default true,   -- false si el plan es ilimitado
  creado_en         timestamptz not null default now(),
  unique (necesidad_id, oferente_id)
);
comment on table desbloqueos is 'Solo se debe insertar vía la función desbloquear_necesidad() — nunca con un INSERT directo del cliente (ver rls.sql).';

create index idx_desbloqueos_necesidad on desbloqueos (necesidad_id);
create index idx_desbloqueos_oferente on desbloqueos (oferente_id);

create table mensajes (
  id            uuid primary key default gen_random_uuid(),
  desbloqueo_id uuid not null references desbloqueos (id) on delete cascade,
  remitente_id  uuid not null references perfiles (id),
  contenido     text,
  adjunto_url   text,
  leido         boolean not null default false,
  creado_en     timestamptz not null default now()
);

create index idx_mensajes_desbloqueo on mensajes (desbloqueo_id);

create table llamadas_programadas (
  id            uuid primary key default gen_random_uuid(),
  desbloqueo_id uuid not null references desbloqueos (id) on delete cascade,
  fecha_hora    timestamptz not null,
  estado        estado_llamada_enum not null default 'programada',
  creado_en     timestamptz not null default now()
);

create table calificaciones (
  id             uuid primary key default gen_random_uuid(),
  desbloqueo_id  uuid not null references desbloqueos (id),
  calificado_por uuid not null references perfiles (id),
  calificacion   numeric(2, 1) not null check (calificacion between 0 and 5),
  comentario     text,
  creado_en      timestamptz not null default now(),
  unique (desbloqueo_id, calificado_por)
);

create table notificaciones (
  id              uuid primary key default gen_random_uuid(),
  destinatario_id uuid not null references perfiles (id),
  tipo            text not null,     -- 'nuevo_desbloqueo' | 'alerta_iac_prioritaria' | 'nuevo_mensaje' | ...
  titulo          text not null,
  cuerpo          text,
  entidad_id      uuid,
  leido           boolean not null default false,
  creado_en       timestamptz not null default now()
);

create index idx_notificaciones_destinatario on notificaciones (destinatario_id, leido);

create table eventos_auditoria (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid references perfiles (id),
  accion     text not null,
  entidad    text,
  entidad_id uuid,
  detalle    jsonb,
  creado_en  timestamptz not null default now()
);


-- ============================================================================
-- IAC / IO — puntajes (ARQUITECTURA.md §6-7)
-- ============================================================================

create table iac_scores (
  id                          uuid primary key default gen_random_uuid(),
  necesidad_id                uuid not null references necesidades (id),
  oferente_id                 uuid not null references perfiles (id),
  puntaje                     numeric(5, 2) not null,
  desglose                    jsonb,   -- puntaje por factor (especialidades, experiencia, ubicación, ...)
  alerta_prioritaria_enviada  boolean not null default false,
  calculado_en                timestamptz not null default now(),
  unique (necesidad_id, oferente_id)
);
comment on table iac_scores is 'Personalizado por par (necesidad, oferente) — nunca general/estático.';

create table io_scores (
  id            uuid primary key default gen_random_uuid(),
  necesidad_id  uuid not null unique references necesidades (id),
  puntaje       numeric(5, 2) not null,
  nivel         text,   -- 'alta' | 'media' | 'baja' — se muestra como nivel, no como % (ARQUITECTURA.md §7)
  desglose      jsonb,
  calculado_en  timestamptz not null default now()
);
comment on table io_scores is 'Un puntaje por ID (no por par) — mismo valor para cualquier oferente que la vea.';


-- ============================================================================
-- Capa 4 (MID) — Predicción de tendencias
-- ============================================================================

create table tendencias_mercado (
  id                     uuid primary key default gen_random_uuid(),
  industria_id           uuid references industrias (id),
  subindustria_id        uuid references industrias (id),
  ciudad                 text,
  periodo                date not null,
  metrica                metrica_tendencia_enum not null,
  valor                  numeric(14, 2) not null,
  valor_periodo_anterior numeric(14, 2),
  variacion_pct          numeric(6, 2),
  tipo_insight           tipo_insight_enum,
  texto_generado         text,
  generado_en            timestamptz not null default now()
);
comment on table tendencias_mercado is 'Poblada por un job periódico (mensual, a calibrar) que compara las vistas de la Capa 3 entre periodos.';


-- ============================================================================
-- Funciones y triggers
-- ============================================================================

-- Crea automáticamente la fila en perfiles cuando alguien se registra en
-- Supabase Auth. El frontend debe enviar tipo_cuenta/nombre/telefono en
-- auth.signUp({ options: { data: { tipo_cuenta, nombre, telefono } } }).
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into perfiles (id, tipo_cuenta, nombre, correo, telefono)
  values (
    new.id,
    coalesce((new.raw_user_meta_data ->> 'tipo_cuenta')::tipo_cuenta_enum, 'proveedor'),
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    new.email,
    new.raw_user_meta_data ->> 'telefono'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

create or replace function set_actualizado_en()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

create trigger trg_necesidades_actualizado_en
  before update on necesidades
  for each row execute function set_actualizado_en();

-- ----------------------------------------------------------------------------
-- desbloquear_necesidad — el mecanismo crítico (ARQUITECTURA.md §10 y §14.2)
-- ----------------------------------------------------------------------------
-- Transacción atómica: verifica créditos (plan activo o crédito de bienvenida),
-- los consume, crea el desbloqueo y notifica al demandante — todo o nada.
-- Es idempotente: si el oferente ya había desbloqueado esta necesidad, devuelve
-- el registro existente sin volver a cobrar (protege contra doble clic).
create or replace function desbloquear_necesidad(p_necesidad_id uuid)
returns desbloqueos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_oferente_id          uuid := auth.uid();
  v_suscripcion_id       uuid;
  v_creditos_disponibles integer;
  v_ilimitado            boolean;
  v_perfil_of            perfiles_oferente%rowtype;
  v_desbloqueo           desbloqueos%rowtype;
begin
  if v_oferente_id is null then
    raise exception 'No autenticado';
  end if;

  select * into v_desbloqueo from desbloqueos
    where necesidad_id = p_necesidad_id and oferente_id = v_oferente_id;
  if found then
    return v_desbloqueo;  -- ya desbloqueada: no cobrar de nuevo
  end if;

  -- Nota: SELECT ... INTO no soporta repartir dos "*" (uno por tabla) en dos
  -- variables de fila en una sola sentencia, por eso se listan las columnas
  -- escalares que realmente se necesitan.
  select s.id, s.creditos_disponibles, p.ilimitado
    into v_suscripcion_id, v_creditos_disponibles, v_ilimitado
    from suscripciones s
    join planes p on p.id = s.plan_id
    where s.oferente_id = v_oferente_id and s.estado = 'activa'
    order by s.fecha_inicio desc
    limit 1
    for update of s;

  if found and (v_ilimitado or coalesce(v_creditos_disponibles, 0) > 0) then
    if not v_ilimitado then
      update suscripciones set creditos_disponibles = creditos_disponibles - 1
        where id = v_suscripcion_id;
    end if;
  else
    select * into v_perfil_of from perfiles_oferente
      where oferente_id = v_oferente_id
      for update;

    if not found or v_perfil_of.credito_bienvenida_usado then
      raise exception 'Sin créditos disponibles. Suscríbete a un plan para desbloquear esta oportunidad.';
    end if;

    update perfiles_oferente set credito_bienvenida_usado = true
      where oferente_id = v_oferente_id;
  end if;

  insert into desbloqueos (necesidad_id, oferente_id, credito_consumido)
    values (p_necesidad_id, v_oferente_id, true)
    returning * into v_desbloqueo;

  insert into notificaciones (destinatario_id, tipo, titulo, cuerpo, entidad_id)
    select n.demandante_id, 'nuevo_desbloqueo', 'Una empresa se interesó en tu necesidad',
           'Revisa quién desbloqueó "' || n.titulo || '" para conversar.', n.id
    from necesidades n where n.id = p_necesidad_id;

  insert into eventos_auditoria (actor_id, accion, entidad, entidad_id, detalle)
    values (v_oferente_id, 'desbloqueo_necesidad', 'necesidades', p_necesidad_id,
            jsonb_build_object('desbloqueo_id', v_desbloqueo.id));

  return v_desbloqueo;
end;
$$;


-- ============================================================================
-- Capa 3 (MID) — Inteligencia de mercado (vistas, siempre agregadas)
-- ============================================================================
-- Regla no negociable (MID doc): nunca exponer una fila individual. Cada vista
-- filtra con HAVING count(*) >= 5 (umbral de partida, sin calibrar todavía —
-- ver "Próximos pasos" en docs/MOTOR-INTELIGENCIA-DEMANDA.md).
--
-- Nota: vista_necesidades_sin_respuesta se implementa aquí como conteo
-- agregado por industria/ciudad (no como listado de IDs individuales) para
-- cumplir la regla de no exponer filas puntuales — el MID doc la describe en
-- prosa sin ese detalle, así que esta es una interpretación mía, no algo ya
-- confirmado contigo.

create view vista_demanda_industria_ciudad as
select
  industria_id,
  ciudad,
  date_trunc('month', creado_en) as periodo,
  count(*) as total_necesidades
from necesidades
group by industria_id, ciudad, date_trunc('month', creado_en)
having count(*) >= 5;

create view vista_presupuestos_predominantes as
select
  industria_id,
  ciudad,
  width_bucket((presupuesto_min + presupuesto_max) / 2.0, 0, 500000000, 10) as rango_bucket,
  count(*) as total
from necesidades
where presupuesto_min is not null and presupuesto_max is not null
group by industria_id, ciudad, rango_bucket
having count(*) >= 5;

create view vista_cobertura_oferta as
with necesidades_agg as (
  select industria_id, ciudad, count(*) as total_necesidades
  from necesidades
  group by industria_id, ciudad
),
oferentes_agg as (
  select e.industria_id, c.ciudad, count(distinct po.oferente_id) as total_oferentes
  from perfiles_oferente po
  cross join lateral unnest(po.especialidades) as e (industria_id)
  cross join lateral unnest(po.ciudades_operacion) as c (ciudad)
  group by e.industria_id, c.ciudad
)
select
  n.industria_id,
  n.ciudad,
  n.total_necesidades,
  coalesce(o.total_oferentes, 0) as total_oferentes
from necesidades_agg n
left join oferentes_agg o on o.industria_id = n.industria_id and o.ciudad = n.ciudad
where n.total_necesidades >= 5;

create view vista_necesidades_sin_respuesta as
select
  industria_id,
  ciudad,
  count(*) as total_sin_respuesta
from necesidades n
where n.creado_en < now() - interval '7 days'
  and not exists (select 1 from desbloqueos d where d.necesidad_id = n.id)
group by industria_id, ciudad
having count(*) >= 5;

create view vista_tiempo_primer_contacto as
select
  n.industria_id,
  n.ciudad,
  date_trunc('month', n.creado_en) as periodo,
  avg(extract(epoch from (primer.fecha_desbloqueo - n.creado_en)) / 3600) as horas_promedio,
  count(*) as muestras
from necesidades n
join lateral (
  select min(d.creado_en) as fecha_desbloqueo from desbloqueos d where d.necesidad_id = n.id
) primer on primer.fecha_desbloqueo is not null
group by n.industria_id, n.ciudad, date_trunc('month', n.creado_en)
having count(*) >= 5;

create view vista_tasa_atencion as
select
  industria_id,
  ciudad,
  periodo,
  count(*) as total_publicadas,
  count(*) filter (where existe_desbloqueo) as total_atendidas,
  round(100.0 * count(*) filter (where existe_desbloqueo) / count(*), 1) as tasa_atencion_pct
from (
  select
    n.industria_id,
    n.ciudad,
    date_trunc('month', n.creado_en) as periodo,
    exists(select 1 from desbloqueos d where d.necesidad_id = n.id) as existe_desbloqueo
  from necesidades n
) sub
group by industria_id, ciudad, periodo
having count(*) >= 5;

create view vista_valor_mercado_generado as
select
  industria_id,
  ciudad,
  date_trunc('month', creado_en) as periodo,
  count(*) as total_necesidades,
  sum((coalesce(presupuesto_min, 0) + coalesce(presupuesto_max, 0)) / 2.0) as valor_generado
from necesidades
group by industria_id, ciudad, date_trunc('month', creado_en)
having count(*) >= 5;
