// Aviso de cookies — se muestra una sola vez por navegador hasta que la
// persona lo acepte. No depende de ninguna cookie de terceros: solo guarda
// una marca en localStorage para no volver a mostrarlo.
// Uso: <script src="cookie-consent.js"></script> y luego
//      initCookieConsent('politica-cookies.html')  (ruta relativa a la página actual)
function initCookieConsent(rutaPolitica){
  var CLAVE = 'promotia_cookies_ok';
  try {
    if (localStorage.getItem(CLAVE)) return;
  } catch (e) {
    return; // localStorage bloqueado (ej. modo privado estricto) — no insistimos.
  }

  var estilo = document.createElement('style');
  estilo.textContent =
    '.cookie-banner{' +
      'position:fixed; right:16px; bottom:16px; left:auto; z-index:80; max-width:min(300px, calc(100vw - 32px));' +
      'background:var(--paper-raised); border:1.5px solid var(--line); border-radius:16px;' +
      'padding:18px 20px; box-shadow:0 20px 45px -20px rgba(0,0,0,.35);' +
      'display:flex; flex-direction:column; gap:12px;' +
      'font-family:"Source Sans 3",ui-sans-serif,system-ui,sans-serif; color:var(--ink);' +
    '}' +
    '.cookie-banner p{font-size:13px; line-height:1.55; margin:0; color:var(--ink);}' +
    '.cookie-banner a{color:var(--blue); font-weight:600; text-decoration:none;}' +
    '.cookie-banner a:hover{text-decoration:underline;}' +
    '.cookie-banner button{' +
      'border:none; cursor:pointer; font-weight:600; font-size:13.5px; padding:10px 20px;' +
      'border-radius:10px; color:#fff; background:linear-gradient(90deg,var(--blue),var(--violet));' +
    '}';
  document.head.appendChild(estilo);

  var banner = document.createElement('div');
  banner.className = 'cookie-banner';
  banner.setAttribute('role', 'region');
  banner.setAttribute('aria-label', 'Aviso de cookies');
  banner.innerHTML =
    '<p>Usamos únicamente el almacenamiento necesario para mantener tu sesión — no usamos cookies de publicidad ni de analítica. ' +
    'Más información en nuestra <a href="' + rutaPolitica + '">Política de Cookies</a>.</p>' +
    '<button type="button">Entendido</button>';

  document.body.appendChild(banner);

  banner.querySelector('button').addEventListener('click', function(){
    try { localStorage.setItem(CLAVE, '1'); } catch (e) {}
    banner.remove();
  });
}
