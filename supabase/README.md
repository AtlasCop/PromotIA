# Base de datos de Promot IA (Supabase)

Esquema completo generado a partir de `docs/ARQUITECTURA.md` (secciones 5-14) y
`docs/MOTOR-INTELIGENCIA-DEMANDA.md` (las 4 capas del MID).

## Cómo correrlo

En el **SQL Editor** de tu proyecto de Supabase, en este orden exacto:

1. `schema.sql` — extensiones, tipos, tablas, índices, funciones/triggers y las 7 vistas de la Capa 3.
2. `rls.sql` — activa Row Level Security y crea las políticas de acceso en cada tabla, más las vistas públicas seguras (`perfiles_publico`, `necesidad_adjuntos_publico`).
3. `seed.sql` — datos base: las 12 industrias de nivel superior y los 3 planes (Bronce/Plata/Oro).

Pensado para correr **una sola vez** sobre un proyecto nuevo — no es idempotente a propósito (mantiene el SQL simple de leer). Si necesitas volver a correrlo, hazlo sobre un proyecto de Supabase limpio.

**No lo he podido probar contra un Postgres real** (no hay `psql`/Docker en este entorno) — lo revisé línea por línea a mano, pero si algún `CREATE`/`ALTER` te da error al pegarlo, dime exactamente cuál y lo corrijo.

## Qué queda cubierto

- **Capa 1 (Captura)**: `necesidades`, `necesidad_adjuntos`, `industrias` (jerárquica).
- **Capa 2 (Perfil de oferente)**: `perfiles_oferente` — el insumo directo del IAC.
- **Capa 3 (Inteligencia de mercado)**: las 7 vistas agregadas, cada una con `HAVING count(*) >= 5` como umbral mínimo de anonimato (sin calibrar todavía, tal como dice el MID doc).
- **Capa 4 (Predicción)**: tabla `tendencias_mercado` (la llena un job periódico que *no* está en este SQL — ver pendientes).
- **Créditos y desbloqueo**: `planes`, `suscripciones`, `desbloqueos`, y la función `desbloquear_necesidad()` — la transacción atómica que exige ARQUITECTURA.md §10/§14 (créditos o crédito de bienvenida, nunca se cobra dos veces por un doble clic, bloquea la fila con `FOR UPDATE` contra condiciones de carrera).
- **Chat y post-venta**: `mensajes`, `llamadas_programadas`, `calificaciones`, `notificaciones`.
- **Seguridad**: RLS en **todas** las tablas, `eventos_auditoria`, y el modelo de teaser público vs. contenido desbloqueado (vistas `_publico` para lo que debe verse sin pagar).
- **IAC / IO**: tablas `iac_scores` / `io_scores` listas para recibir puntajes — el *cálculo* todavía no existe (ver pendientes).

## Decisiones que tomé sin confirmarte (revísalas)

- `necesidades` usa 3 columnas separadas (`descripcion_necesita`/`descripcion_problema`/`descripcion_resultado`) en vez del único campo `descripcion` que menciona el MID doc — porque así es como ya está construido `publicar.html` (3 textareas separadas).
- `vista_necesidades_sin_respuesta` la implementé agregada por industria/ciudad (conteo), no como listado de necesidades puntuales — el MID doc la describe en prosa sin ese detalle, y devolver IDs individuales rompería la regla de "esta capa nunca expone una fila individual" que el mismo documento fija como no negociable.
- Agregué una tabla `admins` vacía + función `es_admin()` como gancho para cuando exista un panel de administración — hoy no la usa nadie.
- Agregué `notificaciones` (no estaba en la lista de tablas de ARQUITECTURA.md §12, pero el paso 6 del mecanismo de desbloqueo en §10 dice explícitamente "se notifica al demandante" — sin esta tabla ese paso quedaba sin implementar).

## Lo que falta para que esto quede realmente conectado

1. **Conectar el frontend**: ninguna de las páginas HTML (`login.html`, `registro.html`, `publicar.html`, `oportunidades.html`, `app/*.html`) llama a Supabase todavía — hoy todas simulan el flujo con JS local. Falta agregar el cliente `@supabase/supabase-js` y reemplazar esos mocks por llamadas reales.
2. **Contrato de registro**: el trigger `handle_new_user()` espera que el signup mande `tipo_cuenta`, `nombre` y `telefono` así:
   ```js
   supabase.auth.signUp({
     email, password,
     options: { data: { tipo_cuenta: 'empresa' /* o 'proveedor' */, nombre, telefono } }
   });
   ```
3. **Stripe**: `suscripciones` tiene `stripe_subscription_id` listo para reconciliar, pero el webhook que confirma pagos y asigna créditos no existe todavía (ARQUITECTURA.md §10 es explícito: nunca asignar créditos porque el frontend "dice" que pagó).
4. **Cálculo de IAC/IO**: las tablas `iac_scores`/`io_scores` existen pero nada las llena todavía — ARQUITECTURA.md §13 sugiere una Supabase Edge Function disparada al publicar una necesidad.
5. **Job de la Capa 4**: `tendencias_mercado` necesita el job periódico (mensual, a calibrar) que compara las vistas de la Capa 3 entre periodos — se puede armar con `pg_cron` (extensión de Supabase) llamando una función que compare snapshots.
6. **Miniaturas de adjuntos**: generarlas automáticamente al subir un archivo (primera página de PDF, recorte de foto, frame de video) — hoy `necesidad_adjuntos.miniatura_url` es solo una columna, nadie la genera.
7. **Verificación de NIT / contacto**: Demanda Verificada (§9) y "Empresa verificada" necesitan integrarse con un proveedor de validación real — por ahora `perfiles_oferente.verificado` y `necesidades.nivel_confianza` son campos manuales.
8. **Rate limiting y backups**: ARQUITECTURA.md §14 los pide explícitamente; son configuración del proyecto de Supabase, no schema SQL.

## Umbral de agregación de la Capa 3

Está fijo en `5` en cada vista (`HAVING count(*) >= 5`). El MID doc dice que es "un punto de partida razonable" pendiente de calibrar con tráfico real — si lo cambias, edítalo en las 7 vistas de `schema.sql` (no hay una constante centralizada; una función `umbral_agregacion()` sería una mejora futura si terminas ajustándolo seguido).
