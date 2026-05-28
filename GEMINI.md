# NFC Souvenirs - Proyecto de Gestión de Memorias NFC

## 🚀 Estado del Proyecto
- **Fase:** Inicialización y Estructura.
- **Backend:** Supabase (Schema definido en `backend/schema.sql`).
- **Mobile:** Flutter (Estructura base en `app/full_app`).
- **Deep Linking:** Configurado en `backend/public/.well-known/`.

## 🛠 Tareas Pendientes
- [ ] Configurar proyecto en el Dashboard de Supabase.
- [ ] Implementar lógica de lectura/escritura NFC en la App.
- [ ] Crear interfaz de galería para el Instant App (Android/iOS).
- [ ] Validar flujos de autenticación.

## ⚙️ Configuración de Deep Linking
Los archivos en `backend/public/.well-known/` deben ser servidos por el dominio `app.tudominio.com` con el tipo de contenido adecuado (`application/json`).
- Android: `assetlinks.json`
- iOS: `apple-app-site-association` (sin extensión)

## 📡 Hardware
- Chip: NTAG215 Anti-Metal.
- Escritura: Ver `scripts/write_tags.py`.
