# Sistema de Gestión Web para FreeRADIUS/DaloRADIUS v2.0

Sistema web completo para crear y gestionar usuarios PPPoE de FreeRADIUS con funcionalidades avanzadas.

## 🎉 Novedades en v2.0

### ✨ Nuevas Características

- ✅ **Edición completa de usuarios** desde la interfaz web
- ✅ **Exportación a CSV/Excel** de todos los usuarios
- ✅ **Gráficos de uso de ancho de banda** con visualización de datos históricos
- ✅ **Historial completo de conexiones** por usuario
- ✅ **Sistema de roles y permisos** (Admin, Operator, Viewer)
- ✅ **Notificaciones por email** para eventos importantes
- ✅ **Webhooks API** para integraciones con sistemas externos
- ✅ **Audit log** para rastrear todas las acciones
- ✅ **Interfaz mejorada** con tabs y mejor organización

### 📋 Características Existentes

- ✅ Crear usuarios PPPoE vía API REST
- ✅ Gestionar velocidades de upload/download por usuario
- ✅ Búsqueda y listado de usuarios
- ✅ Eliminar usuarios
- ✅ Estadísticas en tiempo real
- ✅ Autenticación con API Key
- ✅ Interfaz web moderna y responsive
- ✅ Compatible con equipos Huawei (NE8000-F1A)

## 🚀 Instalación

### Paso 1: Copiar archivos al servidor

```bash
# Si usas Apache
cp radius-api.php /var/www/html/
cp index-v2.html /var/www/html/
cp app.js /var/www/html/
cp styles.css /var/www/html/

# Si usas Nginx
cp radius-api.php /usr/share/nginx/html/
cp index-v2.html /usr/share/nginx/html/
cp app.js /usr/share/nginx/html/
cp styles.css /usr/share/nginx/html/

# Renombrar index-v2.html a index.html
mv /var/www/html/index-v2.html /var/www/html/index.html
```

### Paso 2: Ejecutar migration SQL

Ejecuta el script de migración para crear las nuevas tablas:

```bash
mysql -u radius -p radius < migration_v2.sql
```

Este script creará:
- Tabla `api_users` para gestión de usuarios con roles
- Tabla `audit_log` para registro de eventos
- Tabla `email_notifications` para configurar notificaciones
- Vistas y procedimientos almacenados útiles
- Triggers para audit log automático

### Paso 3: Configurar la API

Edita el archivo `radius-api.php` y configura los parámetros:

```php
// Configuración de la base de datos
define('DB_HOST', 'localhost');
define('DB_NAME', 'radius');
define('DB_USER', 'radius');
define('DB_PASS', 'tu_password_mysql');

// Autenticación
define('API_KEY', 'tu_api_key_secreta_aqui');

// Configuración de email (para notificaciones)
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);
define('SMTP_USER', 'tu_email@gmail.com');
define('SMTP_PASS', 'tu_password_email');
define('SMTP_FROM', 'tu_email@gmail.com');
define('SMTP_FROM_NAME', 'Sistema RADIUS');

// Webhooks
define('WEBHOOKS_ENABLED', true);
```

### Paso 4: Configurar el frontend

Edita el archivo `app.js` y actualiza la URL de la API:

```javascript
const API_URL = 'http://TU_SERVIDOR/radius-api.php';
```

Ejemplo:
```javascript
const API_URL = 'http://192.168.1.100/radius-api.php';
// o
const API_URL = 'https://radius.midominio.com/radius-api.php';
```

### Paso 5: Configurar permisos

```bash
chmod 644 /var/www/html/radius-api.php
chmod 644 /var/www/html/index.html
chmod 644 /var/www/html/app.js
chmod 644 /var/www/html/styles.css

# Asegurar que el usuario web puede escribir webhooks.json
touch /var/www/html/webhooks.json
chown www-data:www-data /var/www/html/webhooks.json
chmod 644 /var/www/html/webhooks.json
```

## 📱 Uso

### Acceder al sistema

1. Abre tu navegador: `http://tu-servidor/index.html`
2. Ingresa tu API Key configurada
3. ¡Listo!

### Gestión de Usuarios

#### Crear Usuario
1. Click en "➕ Crear Usuario"
2. Completa el formulario
3. Click en "Guardar"

#### Editar Usuario
1. Click en "✏️ Editar" en la fila del usuario
2. Modifica los campos necesarios
3. Click en "Guardar"

#### Ver Historial
1. Click en "📊" en la fila del usuario
2. Verás:
   - Gráfico de uso de ancho de banda (últimos 30 días)
   - Tabla con historial completo de conexiones
   - Datos de upload/download por sesión

#### Exportar Usuarios
1. Click en "📥 Exportar CSV"
2. Se descargará un archivo CSV con todos los usuarios

### Webhooks

Los webhooks permiten integrar el sistema con otras aplicaciones.

#### Crear un Webhook

1. Ve a la pestaña "🔗 Webhooks"
2. Click en "➕ Crear Webhook"
3. Ingresa la URL destino
4. Selecciona los eventos a escuchar:
   - `user.created` - Usuario creado
   - `user.updated` - Usuario actualizado
   - `user.deleted` - Usuario eliminado
5. Click en "Guardar"

#### Formato de Webhook

Cuando ocurre un evento, se enviará un POST a tu URL con este formato:

```json
{
  "event": "user.created",
  "data": {
    "username": "usuario@fibra"
  },
  "timestamp": "2024-01-15T10:30:00+00:00"
}
```

## 🔌 API Endpoints

### Endpoints Existentes

```bash
POST   /login          # Autenticación
GET    /users          # Listar usuarios
POST   /users          # Crear usuario
GET    /user           # Obtener usuario
PUT    /user           # Actualizar usuario
DELETE /user           # Eliminar usuario
GET    /stats          # Estadísticas generales
```

### Nuevos Endpoints v2.0

```bash
GET    /export              # Exportar usuarios a CSV
GET    /history             # Historial de conexiones de un usuario
GET    /bandwidth-stats     # Estadísticas de ancho de banda
GET    /webhooks            # Listar webhooks
POST   /webhooks            # Crear webhook
DELETE /webhooks            # Eliminar webhook
```

### Ejemplos de Uso

#### Obtener Historial de Conexiones

```bash
curl -X GET "http://tu-servidor/radius-api.php/history?username=usuario@fibra&limit=50" \
  -H "Authorization: Bearer tu_api_key"
```

#### Obtener Estadísticas de Ancho de Banda

```bash
curl -X GET "http://tu-servidor/radius-api.php/bandwidth-stats?username=usuario@fibra&days=30" \
  -H "Authorization: Bearer tu_api_key"
```

#### Exportar Usuarios a CSV

```bash
curl -X GET "http://tu-servidor/radius-api.php/export?format=csv" \
  -H "Authorization: Bearer tu_api_key" \
  -o usuarios.csv
```

#### Crear Webhook

```bash
curl -X POST "http://tu-servidor/radius-api.php/webhooks" \
  -H "Authorization: Bearer tu_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://mi-servidor.com/webhook",
    "events": ["user.created", "user.deleted"]
  }'
```

## 👥 Sistema de Roles y Permisos

### Roles Disponibles

1. **Viewer** (Nivel 1)
   - Solo lectura
   - Ver usuarios y estadísticas
   - No puede crear, editar o eliminar

2. **Operator** (Nivel 2)
   - Crear y editar usuarios
   - Ver historiales
   - No puede eliminar usuarios ni gestionar webhooks

3. **Admin** (Nivel 3)
   - Acceso completo
   - Todas las operaciones
   - Gestión de webhooks

### Configurar Usuarios API

Para crear usuarios adicionales con roles:

```sql
INSERT INTO api_users (username, api_key, role, email)
VALUES ('operador1', 'clave_segura_operador', 'operator', 'operador@example.com');
```

## 📊 Gráficos y Estadísticas

### Gráfico de Ancho de Banda

El sistema genera automáticamente gráficos de barras mostrando:
- Upload (azul)
- Download (verde)
- Datos de los últimos 30 días

### Métricas Disponibles

- Total de usuarios
- Sesiones activas
- Consumo de ancho de banda por usuario
- Tiempo total de conexión
- Historial completo de sesiones

## 📧 Notificaciones por Email

### Configurar Notificaciones

1. Configura los parámetros SMTP en `radius-api.php`
2. Inserta configuraciones en la tabla `email_notifications`:

```sql
INSERT INTO email_notifications (event_type, recipient_email)
VALUES
('user.created', 'admin@example.com'),
('user.deleted', 'admin@example.com');
```

### Eventos Disponibles

- `user.created` - Se crea un nuevo usuario
- `user.updated` - Se actualiza un usuario
- `user.deleted` - Se elimina un usuario

## 🗄️ Procedimientos Almacenados

### Limpiar Sesiones Antiguas

```sql
-- Eliminar sesiones de más de 90 días
CALL cleanup_old_sessions(90);
```

### Top Usuarios por Consumo

```sql
-- Top 10 usuarios de los últimos 30 días
CALL get_top_bandwidth_users(10, 30);
```

### Formatear Bytes

```sql
SELECT username, format_bytes(SUM(acctinputoctets)) as upload_formatted
FROM radacct
GROUP BY username;
```

## 🔍 Audit Log

Todas las acciones importantes se registran automáticamente en `audit_log`:

```sql
-- Ver últimas acciones
SELECT * FROM audit_log
ORDER BY created_at DESC
LIMIT 50;

-- Ver acciones de un usuario específico
SELECT * FROM audit_log
WHERE username = 'usuario@fibra'
ORDER BY created_at DESC;
```

## 🔒 Seguridad

### Recomendaciones:

1. **Cambia las API Keys** por claves seguras aleatorias
2. **Usa HTTPS** en producción (obligatorio)
3. **Configura CORS** apropiadamente
4. **Restringe acceso** mediante firewall o .htaccess
5. **Backups regulares** de la base de datos
6. **Monitorea el audit_log** para detectar actividad sospechosa
7. **Rotación de API Keys** periódica
8. **Limita intentos de login** (implementar rate limiting)

### Ejemplo .htaccess

```apache
<Files "radius-api.php">
    Order Allow,Deny
    Allow from 192.168.1.0/24
    Allow from tu.ip.publica
</Files>
```

## ⚠️ Troubleshooting

### Error: "No se pueden escribir webhooks"

```bash
chmod 666 /var/www/html/webhooks.json
chown www-data:www-data /var/www/html/webhooks.json
```

### Error: "Tabla api_users no existe"

Ejecuta el script de migración:
```bash
mysql -u radius -p radius < migration_v2.sql
```

### Los gráficos no se muestran

Verifica que el canvas esté visible y que haya datos en `radacct`.

### Webhooks no se disparan

1. Verifica que `WEBHOOKS_ENABLED` sea `true`
2. Verifica que `webhooks.json` tenga permisos de escritura
3. Revisa los logs de PHP para errores de curl

## 📝 Changelog

### Version 2.0 (2024-11)

- ✨ Edición completa de usuarios
- ✨ Exportación a CSV/Excel
- ✨ Gráficos de uso de ancho de banda
- ✨ Historial de conexiones
- ✨ Sistema de roles y permisos
- ✨ Notificaciones por email
- ✨ Webhooks API
- ✨ Audit log
- ✨ Interfaz mejorada con tabs
- ✨ Procedimientos almacenados útiles
- ✨ Mejor organización del código (CSS y JS separados)

### Version 1.0 (2024-10)

- 🎉 Lanzamiento inicial
- ✅ CRUD básico de usuarios
- ✅ Autenticación API Key
- ✅ Estadísticas básicas

## 🤝 Contribuir

Para contribuir al proyecto:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## 📄 Licencia

Este proyecto es de código abierto. Puedes modificarlo según tus necesidades.

## 🆘 Soporte

- **Issues**: https://github.com/SV-Com/RADIUS/issues
- **Documentación FreeRADIUS**: https://freeradius.org/
- **Documentación DaloRADIUS**: https://www.daloradius.com/

---

**Desarrollado con ❤️ para la comunidad**

**⚠️ Nota Importante**: Este sistema interactúa directamente con la base de datos de FreeRADIUS. Realiza backups regulares y prueba en un entorno de desarrollo antes de implementar en producción.
