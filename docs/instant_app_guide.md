# Guía de Configuración: Instant Apps & App Clips

Para que la magia de "escanear y ver sin instalar" funcione, debes configurar los siguientes puntos en las consolas de Google y Apple.

## 1. Comportamiento de la URL
La URL grabada en el imán es: `https://tomas-falcon.github.io/souvenir-config/m/{uuid}`

### Escenario A: El imán tiene contenido (Status: active)
- La Instant App se abre, detecta el UUID, consulta Supabase y muestra la galería.

### Escenario B: El imán está vacío (Status: unassigned)
- La Instant App se abre, detecta que no hay álbum y muestra un botón gigante: **"¡Personaliza este recuerdo! Descarga la App"**.
- Al pulsar, redirige a:
    - Android: `https://play.google.com/store/apps/details?id=com.tusouvenir.app` (ID de ejemplo)
    - iOS: Lanza el `SKOverlay` o redirige a la App Store.

## 2. Configuración en el Servidor (Deep Linking)
Configuración activa en:
1. `https://tomas-falcon.github.io/souvenir-config/.well-known/apple-app-site-association`
2. `https://tomas-falcon.github.io/souvenir-config/.well-known/assetlinks.json`

## 3. Configuración en Flutter (Android Instant App)
En `app/full_app/android/app/src/main/AndroidManifest.xml`, debes añadir el soporte para la URL:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="app.tudominio.com" android:pathPrefix="/m/" />
</intent-filter>
```

## 4. Desarrollo de la Instant App
La estrategia recomendada es crear un proyecto nativo ultra-ligero (SwiftUI / Jetpack Compose) que solo tenga:
1. Lector HTTP para Supabase.
2. Grid de imágenes sencillo.
3. Botón de "Instalar App Completa".

Esto garantiza que el peso sea menor a 15MB, cumpliendo con las reglas de Apple y Google.
