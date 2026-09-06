# Promot IA

Plataforma de inteligencia de demanda: conecta necesidades reales (personas, empresas, entidades públicas, constructoras, comercios) con la oferta que puede resolverlas, y genera inteligencia de mercado a partir de esos datos.

Ver [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) para el plan completo de producto, arquitectura técnica y seguridad.

Este repositorio es independiente del sitio de Atlas Corporation (`Automatización`) — proyectos y marcas distintas, sin compartir historial de git ni despliegue.

## Estructura

- `landing/index.html` — sitio público (Fase 0), antes del login.
- `login.html` — inicio de sesión, distingue cuenta de **empresa** (puede publicar necesidades y buscar oportunidades) de cuenta de **proveedor** (solo puede buscar oportunidades).
- `app/*.html` — pantallas post-login (dashboard, oportunidades, chat, planes, panel de inteligencia).
- `docs/` — plan de producto, arquitectura técnica y política de datos (no se publica en el despliegue).

Todo es HTML estático con Tailwind por CDN — sin build ni backend real todavía.

## Ver el sitio en local

No requiere instalación. Desde la raíz del proyecto:

```bash
python -m http.server 8000
```

Y abre `http://localhost:8000/landing/index.html` (el login está en `http://localhost:8000/login.html`).

## Desplegar en Vercel

El repo ya incluye `vercel.json` (redirige `/` a `landing/index.html`, ya que la raíz real es `login.html`) y `.vercelignore` (excluye `docs/` y `.claude/` del sitio publicado).

Desde la raíz del proyecto, con la CLI de Vercel:

```bash
npx vercel --prod
```

O conectando este repo de GitHub directamente en [vercel.com/new](https://vercel.com/new) — no requiere build command ni framework preset (detéctalo como "Other").
