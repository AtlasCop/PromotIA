// Cierra la sesión automáticamente si el usuario lleva 5 minutos sin interactuar
// con la página. Debe llamarse initSessionTimeout(rutaLogin) SOLO después de
// confirmar que existe una sesión activa (requiere supabaseClient ya creado).
function initSessionTimeout(rutaLogin){
  var LIMITE_MS = 5 * 60 * 1000;
  var temporizador;

  function cerrarPorInactividad(){
    supabaseClient.auth.signOut().then(function(){
      window.location.href = rutaLogin;
    });
  }

  function reiniciarTemporizador(){
    clearTimeout(temporizador);
    temporizador = setTimeout(cerrarPorInactividad, LIMITE_MS);
  }

  ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'].forEach(function(evento){
    document.addEventListener(evento, reiniciarTemporizador, { passive: true });
  });

  reiniciarTemporizador();
}
