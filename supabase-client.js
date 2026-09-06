// Cliente compartido de Supabase — usado por login.html, registro.html y las
// pantallas de app/*.html una vez estén conectadas. Requiere el script UMD de
// supabase-js cargado ANTES que este archivo:
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
//   <script src="supabase-client.js"></script>  (o "../supabase-client.js" desde app/)
var SUPABASE_URL = 'https://bjqcdiowbzqkfpbyifmw.supabase.co';
var SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJqcWNkaW93Ynpxa2ZwYnlpZm13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2NTg5MDEsImV4cCI6MjEwNDIzNDkwMX0.OSRO5Ou-dpTRazY3Lngu9JWKQlkfluitE5jcs19lRmk';

var supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
