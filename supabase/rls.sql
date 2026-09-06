-- ============================================================================
-- Promot IA — Row Level Security + vistas públicas seguras
-- ============================================================================
-- Correr DESPUÉS de schema.sql. Implementa ARQUITECTURA.md §14 (RLS,
-- autenticación real y roles claros) y el modelo de teaser público vs.
-- contenido desbloqueado de §5.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabla mínima de administradores (placeholder — aún no hay panel de admin
-- construido; esto solo deja el gancho para cuando exista).
-- ----------------------------------------------------------------------------

create table admins (
  perfil_id uuid primary key references perfiles (id)
);

create or replace function es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(select 1 from admins where perfil_id = auth.uid());
$$;


-- ============================================================================
-- perfiles
-- ============================================================================
alter table perfiles enable row level security;

create policy "perfiles: uno mismo" on perfiles
  for select using (auth.uid() = id);

-- Un oferente que ya desbloqueó una necesidad de este demandante puede ver
-- sus datos de contacto (correo/telefono) — esto es exactamente "lo
-- desbloqueado" de ARQUITECTURA.md §5.
create policy "perfiles: visible tras desbloqueo" on perfiles
  for select using (
    exists (
      select 1 from necesidades n
      join desbloqueos d on d.necesidad_id = n.id
      where n.demandante_id = perfiles.id and d.oferente_id = auth.uid()
    )
  );

create policy "perfiles: admin" on perfiles
  for select using (es_admin());

create policy "perfiles: actualizar propio" on perfiles
  for update using (auth.uid() = id);

-- El INSERT real lo hace el trigger handle_new_user() (security definer),
-- no el cliente directamente — no se agrega policy de insert para authenticated.

-- Vista pública segura: nombre + tipo de cuenta, sin correo/telefono. Al
-- crearse con el rol de servicio (dueño = postgres), esta vista NO hereda las
-- políticas de RLS de "perfiles" — por eso puede ser pública sin exponer
-- contacto.
create view perfiles_publico as
  select id, nombre, tipo_cuenta from perfiles;

grant select on perfiles_publico to anon, authenticated;


-- ============================================================================
-- perfiles_demandante
-- ============================================================================
alter table perfiles_demandante enable row level security;

create policy "perfiles_demandante: propio" on perfiles_demandante
  for select using (auth.uid() = perfil_id);

create policy "perfiles_demandante: visible tras desbloqueo" on perfiles_demandante
  for select using (
    exists (
      select 1 from necesidades n
      join desbloqueos d on d.necesidad_id = n.id
      where n.demandante_id = perfiles_demandante.perfil_id and d.oferente_id = auth.uid()
    )
  );

create policy "perfiles_demandante: insertar propio" on perfiles_demandante
  for insert with check (
    auth.uid() = perfil_id
    and exists(select 1 from perfiles p where p.id = auth.uid() and p.tipo_cuenta = 'empresa')
  );

create policy "perfiles_demandante: actualizar propio" on perfiles_demandante
  for update using (auth.uid() = perfil_id);


-- ============================================================================
-- industrias — taxonomía pública, de solo lectura para el cliente
-- ============================================================================
alter table industrias enable row level security;

create policy "industrias: lectura pública" on industrias
  for select using (true);
-- Sin policy de insert/update/delete: solo se administra desde el SQL editor
-- o un futuro panel de admin con el rol de servicio.


-- ============================================================================
-- necesidades — el teaser público (ARQUITECTURA.md §5)
-- ============================================================================
alter table necesidades enable row level security;

create policy "necesidades: lectura pública" on necesidades
  for select using (true);

create policy "necesidades: solo empresas publican" on necesidades
  for insert with check (
    demandante_id = auth.uid()
    and exists(select 1 from perfiles p where p.id = auth.uid() and p.tipo_cuenta = 'empresa')
  );

create policy "necesidades: dueño actualiza" on necesidades
  for update using (demandante_id = auth.uid());

create policy "necesidades: dueño elimina" on necesidades
  for delete using (demandante_id = auth.uid());


-- ============================================================================
-- necesidad_adjuntos — miniatura pública, archivo original solo tras desbloqueo
-- ============================================================================
alter table necesidad_adjuntos enable row level security;

create policy "adjuntos: dueño" on necesidad_adjuntos
  for select using (
    exists(select 1 from necesidades n where n.id = necesidad_adjuntos.necesidad_id and n.demandante_id = auth.uid())
  );

create policy "adjuntos: visible tras desbloqueo" on necesidad_adjuntos
  for select using (
    exists(select 1 from desbloqueos d where d.necesidad_id = necesidad_adjuntos.necesidad_id and d.oferente_id = auth.uid())
  );

create policy "adjuntos: dueño inserta" on necesidad_adjuntos
  for insert with check (
    exists(select 1 from necesidades n where n.id = necesidad_adjuntos.necesidad_id and n.demandante_id = auth.uid())
  );

create policy "adjuntos: dueño elimina" on necesidad_adjuntos
  for delete using (
    exists(select 1 from necesidades n where n.id = necesidad_adjuntos.necesidad_id and n.demandante_id = auth.uid())
  );

-- Vista pública: solo la miniatura (el "gancho"), nunca archivo_url.
create view necesidad_adjuntos_publico as
  select id, necesidad_id, miniatura_url, tipo_archivo from necesidad_adjuntos;

grant select on necesidad_adjuntos_publico to anon, authenticated;


-- ============================================================================
-- perfiles_oferente — perfil semi-público (reputación)
-- ============================================================================
alter table perfiles_oferente enable row level security;

create policy "perfiles_oferente: lectura pública" on perfiles_oferente
  for select using (true);

create policy "perfiles_oferente: insertar propio" on perfiles_oferente
  for insert with check (oferente_id = auth.uid());

create policy "perfiles_oferente: actualizar propio" on perfiles_oferente
  for update using (oferente_id = auth.uid());
-- credito_bienvenida_usado también se actualiza desde desbloquear_necesidad()
-- (security definer, no pasa por esta policy).


-- ============================================================================
-- planes — catálogo público de solo lectura
-- ============================================================================
alter table planes enable row level security;

create policy "planes: lectura pública" on planes
  for select using (true);


-- ============================================================================
-- suscripciones — nunca escribibles directamente por el cliente
-- ============================================================================
alter table suscripciones enable row level security;

create policy "suscripciones: propio" on suscripciones
  for select using (oferente_id = auth.uid());

-- Sin policies de insert/update/delete para "authenticated": los créditos y el
-- estado de la suscripción solo deben cambiar vía desbloquear_necesidad()
-- (security definer) o el webhook de Stripe (usando la service_role key, que
-- ignora RLS) — nunca porque el cliente "diga" que pagó (ARQUITECTURA.md §10/§14.2).


-- ============================================================================
-- desbloqueos — solo se crean vía la función atómica
-- ============================================================================
alter table desbloqueos enable row level security;

create policy "desbloqueos: participantes" on desbloqueos
  for select using (
    oferente_id = auth.uid()
    or exists(select 1 from necesidades n where n.id = desbloqueos.necesidad_id and n.demandante_id = auth.uid())
  );

-- Sin policy de insert: todo desbloqueo pasa por desbloquear_necesidad()
-- (security definer), que valida créditos antes de insertar — un INSERT
-- directo del cliente saltaría esa validación.


-- ============================================================================
-- mensajes / llamadas_programadas / calificaciones — solo entre participantes
-- ============================================================================
alter table mensajes enable row level security;

create policy "mensajes: participantes leen" on mensajes
  for select using (
    exists (
      select 1 from desbloqueos d
      where d.id = mensajes.desbloqueo_id
        and (d.oferente_id = auth.uid()
             or exists(select 1 from necesidades n where n.id = d.necesidad_id and n.demandante_id = auth.uid()))
    )
  );

create policy "mensajes: participantes escriben" on mensajes
  for insert with check (
    remitente_id = auth.uid()
    and exists (
      select 1 from desbloqueos d
      where d.id = mensajes.desbloqueo_id
        and (d.oferente_id = auth.uid()
             or exists(select 1 from necesidades n where n.id = d.necesidad_id and n.demandante_id = auth.uid()))
    )
  );

alter table llamadas_programadas enable row level security;

create policy "llamadas: participantes" on llamadas_programadas
  for all using (
    exists (
      select 1 from desbloqueos d
      where d.id = llamadas_programadas.desbloqueo_id
        and (d.oferente_id = auth.uid()
             or exists(select 1 from necesidades n where n.id = d.necesidad_id and n.demandante_id = auth.uid()))
    )
  );

alter table calificaciones enable row level security;

create policy "calificaciones: participantes leen" on calificaciones
  for select using (
    exists (
      select 1 from desbloqueos d
      where d.id = calificaciones.desbloqueo_id
        and (d.oferente_id = auth.uid()
             or exists(select 1 from necesidades n where n.id = d.necesidad_id and n.demandante_id = auth.uid()))
    )
  );

create policy "calificaciones: demandante califica" on calificaciones
  for insert with check (
    calificado_por = auth.uid()
    and exists (
      select 1 from desbloqueos d
      join necesidades n on n.id = d.necesidad_id
      where d.id = calificaciones.desbloqueo_id and n.demandante_id = auth.uid()
    )
  );


-- ============================================================================
-- notificaciones
-- ============================================================================
alter table notificaciones enable row level security;

create policy "notificaciones: propio" on notificaciones
  for select using (destinatario_id = auth.uid());

create policy "notificaciones: marcar leído" on notificaciones
  for update using (destinatario_id = auth.uid())
  with check (destinatario_id = auth.uid());
-- Sin policy de insert: se crean desde funciones security definer
-- (ej. desbloquear_necesidad) o el service role.


-- ============================================================================
-- eventos_auditoria — solo admin lee, nadie escribe directo
-- ============================================================================
alter table eventos_auditoria enable row level security;

create policy "auditoria: solo admin" on eventos_auditoria
  for select using (es_admin());


-- ============================================================================
-- iac_scores / io_scores
-- ============================================================================
alter table iac_scores enable row level security;

create policy "iac_scores: propio del oferente" on iac_scores
  for select using (oferente_id = auth.uid());
-- Sin policy de insert/update: los calcula un job/función automática
-- (Fase 2 — todavía no implementada como Edge Function, ver README).

alter table io_scores enable row level security;

create policy "io_scores: lectura pública" on io_scores
  for select using (true);
-- El IO se muestra junto a la necesidad en el feed público (ARQUITECTURA.md §7)
-- así que no es sensible como el IAC.


-- ============================================================================
-- tendencias_mercado — agregado público (Observatorio, gratuito por ahora)
-- ============================================================================
alter table tendencias_mercado enable row level security;

create policy "tendencias: lectura pública" on tendencias_mercado
  for select using (true);


-- ============================================================================
-- Grants sobre las vistas de la Capa 3 (agregadas, sin RLS propia porque no
-- exponen filas individuales — el umbral de 5 muestras en cada HAVING es la
-- protección de privacidad, no RLS por fila).
-- ============================================================================
grant select on
  vista_demanda_industria_ciudad,
  vista_presupuestos_predominantes,
  vista_cobertura_oferta,
  vista_necesidades_sin_respuesta,
  vista_tiempo_primer_contacto,
  vista_tasa_atencion,
  vista_valor_mercado_generado
to anon, authenticated;

grant execute on function desbloquear_necesidad(uuid) to authenticated;
