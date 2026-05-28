class AppSettings {
  // --- Supabase Configuration ---
  static const String supabaseUrl = 'https://apknmsbrbmtjidmrngnk.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_1ZymSc3eQia5scNC2mmWXw_ke1Wlppb';

  // --- Deep Linking & Redirects ---
  // Esta es la URL a la que Supabase enviará los correos de confirmación.
  // Debe coincidir con lo que pongas en el Dashboard de Supabase -> Auth -> Site URL.
  static const String siteUrl = 'https://tomas-falcon.github.io/souvenir-config';
  
  // --- App Info ---
  static const String appName = 'NFC Souvenirs';
  static const String appVersion = '1.0.0+3';
  
  // --- Monetization Limits (Future) ---
  static const int maxFreePhotos = 20;
}
