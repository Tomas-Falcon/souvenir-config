# NFC Souvenirs - Web Application Documentation

Esta es la documentación oficial de la versión web de NFC Souvenirs, diseñada para gestionar recuerdos físicos vinculados a tags NFC.

## 🚀 Descripción General
La aplicación web (`index.html`) actúa como el centro de control para los dueños de los souvenirs. Permite gestionar álbumes, controlar la privacidad y responder a solicitudes de acceso desde cualquier navegador.

## 🛠 Funcionalidades Principales

### 1. Dashboard (Inicio)
- **Estadísticas en tiempo real:** Visualización de álbumes activos, cantidad de archivos multimedia y total de escaneos detectados.
- **Actividad Reciente:** Historial de los últimos escaneos realizados en los imanes del usuario.

### 2. Gestión de Álbumes
- **Visualización en Grid:** Lista de todos los recuerdos vinculados con sus portadas y estados de privacidad.
- **Editor de Álbum:**
    - Cambio de título.
    - Configuración de privacidad (Público, Protegido, Privado).
    - Eliminación de álbumes (desvincula el tag NFC automáticamente).

### 3. Sistema de Privacidad y Permisos
- **Público:** Cualquier persona que escanee el imán puede ver las fotos instantáneamente.
- **Protegido:** El visitante debe solicitar acceso. El dueño recibe una notificación en la sección de "Solicitudes" de la web para aprobar o rechazar.
- **Privado:** Solo el dueño puede ver el contenido desde su cuenta.

### 4. Gestión de Solicitudes
- Panel dedicado para gestionar peticiones de acceso pendientes.
- Acciones rápidas para Aceptar o Rechazar visitantes.

### 5. Gestión de Cuenta
- Autenticación segura mediante Supabase Auth.
- Cierre de sesión y protección de rutas.

## 📱 Diseño Responsive
La web está optimizada para:
- **Desktop:** Navegación lateral persistente y grids amplios.
- **Mobile:** Menú hamburguesa, navegación táctil y diseño adaptado a pantallas pequeñas para gestión "on-the-go".

## 🔧 Detalles Técnicos
- **Tecnologías:** HTML5, Vanilla CSS3 (Custom Properties), Vanilla JS (ES6+).
- **Backend:** Supabase (PostgreSQL + Auth + Storage).
- **Integración NFC:** La web detecta los escaneos mediante la función `log_album_scan` en el backend, permitiendo ver la actividad de los imanes físicos en tiempo real.

---
*Nota: Para vincular nuevos imanes, se recomienda utilizar la App Móvil nativa debido a las limitaciones de lectura NFC en navegadores web.*
