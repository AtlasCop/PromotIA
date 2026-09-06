-- ============================================================================
-- Promot IA — Datos semilla
-- ============================================================================
-- Correr DESPUÉS de schema.sql y rls.sql (se ejecuta como el rol de servicio
-- del SQL editor, así que las políticas de RLS no bloquean estos inserts).
-- ============================================================================

-- Taxonomía de industrias — nivel superior, igual al arreglo TAXONOMIA
-- compartido entre landing/index.html, registro.html y publicar.html.
-- "Otro" NO se guarda aquí a propósito: es una opción de escape del
-- formulario, no un nodo real de taxonomía.
insert into industrias (nombre) values
  ('Construcción y obra civil'),
  ('Ingeniería civil y estructural'),
  ('Arquitectura y diseño'),
  ('Ingeniería eléctrica'),
  ('Ingeniería mecánica e industrial'),
  ('Ingeniería hidráulica y sanitaria'),
  ('Telecomunicaciones y edificios inteligentes'),
  ('Gerencia y consultoría de proyectos'),
  ('Sostenibilidad y certificaciones'),
  ('Equipos, maquinaria y logística'),
  ('Seguridad industrial y SST'),
  ('Servicios especializados de cierre de obra');

-- Planes de créditos (ARQUITECTURA.md §10) — descuento anual 10% ya es el
-- default de la tabla.
insert into planes (nombre, creditos_mensuales, ilimitado, precio_mensual_usd) values
  ('bronce', 1, false, 19.00),
  ('plata', 10, false, 99.00),
  ('oro', null, true, 299.00);
