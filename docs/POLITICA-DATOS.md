# Política de Tratamiento de Datos Personales — Promot IA

> **BORRADOR — pendiente de revisión por un abogado antes de publicarse.** Este documento es un punto de partida técnico/funcional basado en la Ley 1581 de 2012 y el Decreto 1377 de 2013 (Colombia), redactado para reflejar el mecanismo real de Promot IA — en particular, que los datos de contacto de un demandante se revelan a un tercero (el oferente) a cambio de un pago que este último realiza, y que se genera una miniatura pública de cada adjunto. Antes de publicarlo en producción, debe ser revisado por un abogado y completado con el NIT y el correo de contacto definitivos de Atlas Corporation S.A.S.

## 1. Responsable del tratamiento

**Promot IA es una marca de Atlas Corporation S.A.S.** (confirmado — Atlas Corporation S.A.S. es la empresa dueña de la idea y opera la plataforma bajo esta marca), con domicilio en Medellín, Colombia. NIT: [pendiente]. Correo de contacto para temas de datos personales: [pendiente — definir un correo dedicado, ej. `datos@promotia.co`].

## 2. Definiciones clave

- **Titular**: la persona natural cuyos datos se recolectan (quien publica una Intención de Demanda, o el contacto registrado por una empresa).
- **Intención de Demanda (ID)**: la necesidad publicada por un demandante en la plataforma.
- **Demandante**: quien publica una ID.
- **Oferente**: la empresa que paga por acceder a los datos de contacto de una ID.
- **Desbloqueo**: el acto de un oferente de pagar (con un crédito de su plan) para acceder a los datos de contacto y adjuntos de una ID específica.

## 3. Datos que recolectamos

- **Datos de cuenta**: nombre, correo, teléfono, empresa (si aplica), tipo y número de documento.
- **Datos de la Intención de Demanda**: título, industria, país, ciudad, presupuesto estimado, descripción, urgencia.
- **Adjuntos**: archivos que el demandante decida subir (PDF, planos, fotos, videos) — pueden contener datos personales o de terceros; el demandante es responsable de contar con autorización para compartirlos si incluyen datos de personas distintas a él. **De cada adjunto se genera además una miniatura/vista previa que se muestra públicamente** (a cualquier oferente, sin necesidad de pagar) como incentivo para el desbloqueo — el demandante debe ser informado de esto explícitamente al subir el archivo, ya que implica un nivel de exposición pública distinto al del archivo completo.
- **Datos de uso**: mensajes del chat interno, historial de desbloqueos, tiempos de respuesta, metadatos de navegación.
- **Datos de pago**: Promot IA **no almacena datos de tarjetas** — el procesamiento de pagos lo realiza un tercero certificado (ej. Stripe), que entrega a Promot IA solo la confirmación del pago, nunca el número de tarjeta completo.

## 4. Finalidades del tratamiento

1. Operar la plataforma: publicar y clasificar Intenciones de Demanda, permitir el descubrimiento por parte de oferentes.
2. **Revelar los datos de contacto y adjuntos de una ID a la(s) empresa(s) que la desbloqueen mediante pago** — esta es la finalidad central y más sensible del tratamiento; se explica en detalle en la sección 6.
3. Procesar pagos y gestionar suscripciones/créditos.
4. Habilitar y registrar la comunicación entre demandante y oferente dentro del chat interno.
5. Generar métricas de calidad (tiempo de respuesta, tasa de conversión) para calificar oferentes.
6. Generar reportes agregados y **anonimizados** de tendencias de demanda (inteligencia de mercado) — en ningún caso estos reportes exponen datos que permitan identificar a una persona o empresa puntual.
7. Seguridad, prevención de fraude y cumplimiento de obligaciones legales.

## 5. Autorización del titular

Al crear una cuenta y publicar una Intención de Demanda, el demandante acepta expresamente que **sus datos de contacto y los adjuntos de esa ID serán revelados a las empresas que decidan pagar por desbloquearla**. Esta autorización se solicita de forma clara y explícita en el propio formulario de publicación (checkbox de aceptación), no solo mediante un enlace genérico a esta política — dado que es el punto más sensible del producto, no basta con un aviso pasivo.

## 6. El mecanismo de desbloqueo, explicado en términos de datos personales

Esta sección existe porque el mecanismo central de Promot IA es, en esencia, un tratamiento de datos personales condicionado a un pago hecho por un tercero — algo que debe quedar descrito sin ambigüedad:

- Antes de que cualquier oferente pague, solo se muestra la información **no identificable** de la ID: título, industria, ciudad, rango de presupuesto, urgencia, descripción y una **miniatura/vista previa reducida** de cada adjunto. **No se muestran datos de contacto ni el archivo original de los adjuntos.**
- Cuando un oferente paga (consume un crédito) para desbloquear una ID específica, se revelan a **ese oferente en particular** los datos de contacto del demandante y los archivos adjuntos completos (en su resolución/calidad original).
- Una misma ID puede ser desbloqueada por varias empresas distintas; cada una paga su propio desbloqueo y accede a los mismos datos de contacto.
- El demandante puede ver qué empresas han desbloqueado su ID.
- El dinero del desbloqueo lo paga el oferente a Promot IA — el demandante nunca paga por publicar ni por recibir interés.

## 7. Transferencia y transmisión de datos a terceros

- **Procesador de pagos** (ej. Stripe): recibe los datos necesarios para procesar el cobro al oferente; no participa en el tratamiento de los datos del demandante.
- **Proveedores de infraestructura** (ej. Supabase, Vercel): almacenan y sirven los datos de la plataforma; pueden operar con servidores fuera de Colombia, lo que constituye una **transferencia internacional de datos** — se informará el/los país(es) exactos una vez se confirme la infraestructura definitiva, conforme a lo exigido por la Ley 1581 de 2012 para este tipo de transferencias.
- Promot IA no vende ni comparte datos de contacto con nadie fuera de este mecanismo (es decir, nunca se entregan datos de contacto a una empresa que no haya pagado el desbloqueo correspondiente).

## 8. Derechos de los titulares

Conforme a la Ley 1581 de 2012, todo titular tiene derecho a:

- Conocer, actualizar y rectificar sus datos personales.
- Solicitar prueba de la autorización otorgada.
- Ser informado sobre el uso que se ha dado a sus datos.
- Presentar quejas ante la Superintendencia de Industria y Comercio (SIC) por infracciones a la ley.
- Revocar la autorización y/o solicitar la supresión de sus datos, cuando no exista un deber legal o contractual que impida eliminarlos.
- Acceder de forma gratuita a sus datos personales.

## 9. Cómo ejercer estos derechos

Cualquier solicitud puede enviarse a [correo de contacto pendiente]. Los tiempos de respuesta siguen lo establecido por la ley: consultas en máximo 10 días hábiles, reclamos en máximo 15 días hábiles (con posibilidad de una prórroga de 8 días hábiles adicionales, notificando al titular).

## 10. Seguridad de la información

Promot IA aplica medidas técnicas y administrativas para proteger los datos personales, incluyendo control de acceso basado en roles, cifrado en tránsito y en reposo, y registro de auditoría de accesos — ver el detalle técnico en `docs/ARQUITECTURA.md`, sección de Seguridad.

## 11. Menores de edad

La plataforma no está dirigida a menores de edad; no se permite el registro de personas menores de 18 años.

## 12. Vigencia y modificaciones

Esta política puede actualizarse; los cambios sustanciales se notificarán a los usuarios registrados. Última actualización: [pendiente de fecha de publicación real].

## 13. Aceptación

El uso de la plataforma implica la aceptación de esta política, sin perjuicio de las autorizaciones específicas solicitadas en momentos puntuales del producto (como la publicación de una Intención de Demanda, descrita en la sección 5).
