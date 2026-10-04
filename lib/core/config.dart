/// Multiplayer backend (Supabase). Fill these in, pass them at build time:
///   flutter build apk --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_xxx
/// or enter them in the app (Réglages → Serveur multijoueur).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
}
