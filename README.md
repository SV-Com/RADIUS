# Sistema de Gestión Web para FreeRADIUS/DaloRADIUS

Sistema web completo para crear y gestionar usuarios PPPoE de FreeRADIUS sin necesidad de acceder a DaloRADIUS.

## 📋 Características

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

Copia los archivos al directorio web de tu servidor:

```bash
# Si usas Apache
cp radius-api.php /var/www/html/
cp index.html /var/www/html/

# Si usas Nginx
cp radius-api.php /usr/share/nginx/html/
cp index.html /usr/share/nginx/html/
```

### Paso 2: Configurar la API

Edita el archivo `radius-api.php` y configura los siguientes parámetros:

```php
// Configuración de la base de datos
define('DB_HOST', 'localhost');          // Host de MySQL
define('DB_NAME', 'radius');             // Nombre de la BD (generalmente 'radius')
define('DB_USER', 'radius');             // Usuario de MySQL
define('DB_PASS', 'tu_password_mysql');  // Contraseña de MySQL

// Autenticación - CAMBIA ESTO POR UNA CLAVE SEGURA
define('API_KEY', 'tu_api_key_secreta_aqui');
```

### Paso 3: Configurar el frontend

Edita el archivo `index.html` y actualiza la URL de la API:

```javascript
// Línea 351 aproximadamente
const API_URL = 'http://TU_SERVIDOR/radius-api.php';
```

Ejemplo:
```javascript
const API_URL = 'http://192.168.1.100/radius-api.php';
// o
const API_URL = 'https://radius.midominio.com/radius-api.php';
```

### Paso 4: Configurar permisos

```bash
# Dar permisos de ejecución al archivo PHP
chmod 644 /var/www/html/radius-api.php
chmod 644 /var/www/html/index.html

# Asegurar que el usuario de Apache/Nginx puede leer los archivos
chown www-data:www-data /var/www/html/radius-api.php
chown www-data:www-data /var/www/html/index.html
```

### Paso 5: Configurar PHP (si es necesario)

Asegúrate de que PHP tenga las extensiones necesarias:

```bash
# En Debian/Ubuntu
apt-get install php-mysql php-pdo

# Reiniciar el servidor web
systemctl restart apache2
# o
systemctl restart nginx && systemctl restart php-fpm
```

## 🔧 Configuración de CORS (si API y frontend están en diferentes dominios)

Si tu API y el frontend están en diferentes servidores, ya está configurado CORS en la API.

Si necesitas restringir el acceso, modifica estas líneas en `radius-api.php`:

```php
// Cambiar esta línea:
header('Access-Control-Allow-Origin: *');

// Por esta (especificando tu dominio):
header('Access-Control-Allow-Origin: https://tudominio.com');
```

## 📱 Uso

### Acceder al sistema

1. Abre tu navegador y ve a: `http://tu-servidor/index.html`
2. Ingresa tu API Key configurada en el paso 2
3. ¡Listo! Ya puedes gestionar usuarios

### Crear un usuario PPPoE

1. Click en "➕ Crear Usuario"
2. Completa el formulario:
   - **Usuario**: nombre@dominio (ej: usuario1@fibra)
   - **Contraseña**: contraseña del usuario
   - **Velocidad Upload**: 10M, 20M, 50M, 100M (o en Kbps: 10240)
   - **Velocidad Download**: 10M, 20M, 50M, 100M
   - **Perfil**: (opcional) nombre del perfil/grupo

3. Click en "Guardar"

### Formato de velocidades

El sistema acepta dos formatos:
- **Megabits**: `10M`, `20M`, `50M`, `100M`
- **Kilobits**: `10240`, `20480`, `51200`, `102400`

## 🔌 API Endpoints

### Autenticación

```bash
POST /radius-api.php/login
Content-Type: application/json

{
    "api_key": "tu_api_key_secreta_aqui"
}
```

### Listar usuarios

```bash
GET /radius-api.php/users?limit=50&offset=0&search=usuario
Authorization: Bearer tu_api_key_secreta_aqui
```

### Crear usuario

```bash
POST /radius-api.php/users
Authorization: Bearer tu_api_key_secreta_aqui
Content-Type: application/json

{
    "username": "usuario1@fibra",
    "password": "mi_password",
    "bandwidth_up": "10M",
    "bandwidth_down": "10M",
    "profile": "default"
}
```

### Obtener un usuario

```bash
GET /radius-api.php/user?username=usuario1@fibra
Authorization: Bearer tu_api_key_secreta_aqui
```

### Actualizar usuario

```bash
PUT /radius-api.php/user
Authorization: Bearer tu_api_key_secreta_aqui
Content-Type: application/json

{
    "username": "usuario1@fibra",
    "password": "nueva_password",
    "bandwidth_up": "20M",
    "bandwidth_down": "20M"
}
```

### Eliminar usuario

```bash
DELETE /radius-api.php/user?username=usuario1@fibra
Authorization: Bearer tu_api_key_secreta_aqui
```

### Estadísticas

```bash
GET /radius-api.php/stats
Authorization: Bearer tu_api_key_secreta_aqui
```

## 🔍 Ejemplo de uso con cURL

```bash
# Login
curl -X POST http://tu-servidor/radius-api.php/login \
  -H "Content-Type: application/json" \
  -d '{"api_key":"tu_api_key_secreta_aqui"}'

# Crear usuario
curl -X POST http://tu-servidor/radius-api.php/users \
  -H "Authorization: Bearer tu_api_key_secreta_aqui" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "cliente1@fibra",
    "password": "pass123",
    "bandwidth_up": "50M",
    "bandwidth_down": "50M"
  }'

# Listar usuarios
curl -X GET "http://tu-servidor/radius-api.php/users?limit=10" \
  -H "Authorization: Bearer tu_api_key_secreta_aqui"

# Eliminar usuario
curl -X DELETE "http://tu-servidor/radius-api.php/user?username=cliente1@fibra" \
  -H "Authorization: Bearer tu_api_key_secreta_aqui"
```

## 🛠️ Integración con Huawei NE8000-F1A

El sistema está configurado para usar los atributos RADIUS de Huawei:

- `Huawei-Input-Average-Rate`: Velocidad de upload
- `Huawei-Output-Average-Rate`: Velocidad de download

Estos atributos son compatibles con el NE8000-F1A para control de ancho de banda.

## 📊 Estructura de la Base de Datos

El sistema interactúa con las siguientes tablas de FreeRADIUS:

- **radcheck**: Credenciales de autenticación
- **radreply**: Atributos de respuesta (velocidades)
- **radusergroup**: Asignación de perfiles/grupos
- **radacct**: Sesiones activas (solo lectura)
- **userinfo**: Información adicional del usuario

## 🔒 Seguridad

### Recomendaciones:

1. **Cambia la API Key por defecto** en `radius-api.php`
2. **Usa HTTPS** en producción
3. **Configura CORS** apropiadamente si es necesario
4. **Restringe el acceso** al archivo PHP mediante firewall o `.htaccess`
5. **Usa contraseñas fuertes** para MySQL

### Ejemplo .htaccess para proteger la API:

```apache
<Files "radius-api.php">
    Order Allow,Deny
    Allow from 192.168.1.0/24
    Allow from tu.ip.publica
</Files>
```

## ⚠️ Troubleshooting

### Error: "No autorizado"
- Verifica que la API Key sea correcta
- Asegúrate de estar enviando el header `Authorization`

### Error: "Error al conectar con la base de datos"
- Verifica las credenciales de MySQL en `radius-api.php`
- Asegúrate de que el usuario tiene permisos sobre la BD radius
- Verifica que el servicio MySQL esté corriendo

### Los usuarios no se crean
- Verifica los logs de PHP: `/var/log/apache2/error.log` o `/var/log/nginx/error.log`
- Asegúrate de que las extensiones PHP (pdo_mysql) estén instaladas
- Verifica permisos del usuario MySQL

### CORS errors en el navegador
- Asegúrate de que la API esté respondiendo con los headers CORS correctos
- Verifica la configuración de `Access-Control-Allow-Origin` en la API

## 📝 Logs

Para ver los logs de la aplicación:

```bash
# Apache
tail -f /var/log/apache2/error.log
tail -f /var/log/apache2/access.log

# Nginx
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log

# PHP-FPM
tail -f /var/log/php-fpm/www-error.log
```

## 🎯 Próximas mejoras sugeridas

- [ ] Edición completa de usuarios desde la interfaz
- [ ] Exportación de usuarios a CSV/Excel
- [ ] Gráficos de uso de ancho de banda
- [ ] Historial de conexiones por usuario
- [ ] Sistema de roles y permisos múltiples
- [ ] Notificaciones por email
- [ ] API webhooks para integraciones

## 📄 Licencia

Este sistema es de uso libre. Puedes modificarlo según tus necesidades.

## 🤝 Soporte

Para soporte adicional o consultas:
- Revisa la documentación de FreeRADIUS: https://freeradius.org/
- Revisa la documentación de DaloRADIUS: https://www.daloradius.com/

---

**Nota**: Este sistema interactúa directamente con la base de datos de FreeRADIUS/DaloRADIUS. Asegúrate de hacer backups regulares de tu base de datos.
