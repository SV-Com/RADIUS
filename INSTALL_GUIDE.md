# Guía de Instalación Completa - Debian 12 / Ubuntu

Sistema de Gestión Web para FreeRADIUS v2.0

## 📋 Requisitos

- Debian 12 o Ubuntu 22.04+
- Acceso root o sudo
- Conexión a Internet
- Mínimo 2GB RAM
- 20GB espacio en disco

## 🚀 Método 1: Instalación Automática (Recomendado)

### Paso 1: Descargar el instalador

```bash
# Descargar el script
wget https://raw.githubusercontent.com/SV-Com/RADIUS/main/install-debian12.sh

# O si tienes el repositorio clonado
cd RADIUS
```

### Paso 2: Dar permisos de ejecución

```bash
chmod +x install-debian12.sh
```

### Paso 3: Ejecutar el instalador

```bash
sudo bash install-debian12.sh
```

El script te preguntará:
- Si deseas crear una nueva base de datos
- Nombre de la base de datos (default: radius)
- Usuario de la base de datos (default: radiususer)
- Contraseña del usuario

### Paso 4: Acceder al sistema

Al finalizar, el script mostrará:
- URL de acceso
- API Key generada

```
URL de acceso: http://TU_IP/radius/
API Key: [clave generada automáticamente]
```

**¡Listo!** Ya puedes acceder al sistema con tu API Key.

---

## 🔧 Método 2: Instalación Manual

### Paso 1: Actualizar el sistema

```bash
sudo apt update
sudo apt upgrade -y
```

### Paso 2: Instalar Apache2

```bash
sudo apt install -y apache2

# Habilitar módulos necesarios
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod ssl

# Iniciar y habilitar Apache
sudo systemctl start apache2
sudo systemctl enable apache2
```

### Paso 3: Instalar PHP 8.2

```bash
sudo apt install -y php php-cli php-fpm php-mysql php-pdo \
    php-mbstring php-curl php-xml php-zip php-gd php-json \
    libapache2-mod-php

# Reiniciar Apache
sudo systemctl restart apache2

# Verificar instalación
php -v
```

### Paso 4: Instalar MariaDB

```bash
sudo apt install -y mariadb-server mariadb-client

# Iniciar y habilitar MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Asegurar instalación (RECOMENDADO)
sudo mysql_secure_installation
```

Responde a las preguntas:
- Set root password? [Y/n]: **Y** (establece una contraseña segura)
- Remove anonymous users? [Y/n]: **Y**
- Disallow root login remotely? [Y/n]: **Y**
- Remove test database? [Y/n]: **Y**
- Reload privilege tables? [Y/n]: **Y**

### Paso 5: Instalar FreeRADIUS

```bash
sudo apt install -y freeradius freeradius-mysql freeradius-utils

# Iniciar y habilitar FreeRADIUS
sudo systemctl start freeradius
sudo systemctl enable freeradius
```

### Paso 6: Crear Base de Datos

```bash
# Acceder a MySQL
sudo mysql -u root -p

# Dentro de MySQL, ejecutar:
```

```sql
-- Crear base de datos
CREATE DATABASE radius CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario
CREATE USER 'radiususer'@'localhost' IDENTIFIED BY 'TU_PASSWORD_SEGURA';

-- Otorgar permisos
GRANT ALL PRIVILEGES ON radius.* TO 'radiususer'@'localhost';
FLUSH PRIVILEGES;

-- Salir
EXIT;
```

### Paso 7: Importar esquema de FreeRADIUS

```bash
# Importar esquema base de FreeRADIUS
sudo mysql -u root -p radius < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
```

### Paso 8: Descargar archivos del proyecto

```bash
# Crear directorio web
sudo mkdir -p /var/www/html/radius
cd /tmp

# Clonar repositorio
git clone https://github.com/SV-Com/RADIUS.git
cd RADIUS

# Copiar archivos
sudo cp radius-api.php /var/www/html/radius/
sudo cp app.js /var/www/html/radius/
sudo cp styles.css /var/www/html/radius/
sudo cp index-v2.html /var/www/html/radius/index.html

# Crear archivo para webhooks
sudo touch /var/www/html/radius/webhooks.json
```

### Paso 9: Configurar la API

```bash
sudo nano /var/www/html/radius/radius-api.php
```

Edita las siguientes líneas:

```php
// Configuración de la base de datos
define('DB_HOST', 'localhost');
define('DB_NAME', 'radius');
define('DB_USER', 'radiususer');
define('DB_PASS', 'TU_PASSWORD_SEGURA');

// Autenticación - GENERA UNA CLAVE ALEATORIA
define('API_KEY', 'genera_una_clave_aleatoria_aqui');

// Email (opcional - configúralo si vas a usar notificaciones)
define('SMTP_USER', 'tu_email@gmail.com');
define('SMTP_PASS', 'tu_password_app');
```

**Para generar una API Key aleatoria:**
```bash
openssl rand -hex 32
```

Guarda y cierra el archivo (Ctrl+O, Enter, Ctrl+X).

### Paso 10: Configurar el frontend

```bash
sudo nano /var/www/html/radius/app.js
```

Busca la línea:
```javascript
const API_URL = 'http://TU_SERVIDOR/radius-api.php';
```

Cámbiala por (reemplaza TU_IP por la IP de tu servidor):
```javascript
const API_URL = 'http://TU_IP/radius/radius-api.php';
```

### Paso 11: Importar tablas adicionales (v2.0)

```bash
cd /tmp/RADIUS
sudo mysql -u root -p radius < migration_v2.sql
```

### Paso 12: Configurar permisos

```bash
sudo chown -R www-data:www-data /var/www/html/radius
sudo chmod -R 755 /var/www/html/radius
sudo chmod 666 /var/www/html/radius/webhooks.json
```

### Paso 13: Configurar VirtualHost de Apache

```bash
sudo nano /etc/apache2/sites-available/radius.conf
```

Pega el siguiente contenido:

```apache
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/radius

    <Directory /var/www/html/radius>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        # Seguridad para la API
        <Files "radius-api.php">
            # Para restringir por IP, descomenta:
            # Order Allow,Deny
            # Allow from 192.168.1.0/24
            # Allow from TU_IP
        </Files>
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/radius-error.log
    CustomLog ${APACHE_LOG_DIR}/radius-access.log combined
</VirtualHost>
```

Guarda y cierra.

```bash
# Deshabilitar sitio por defecto
sudo a2dissite 000-default.conf

# Habilitar nuestro sitio
sudo a2ensite radius.conf

# Recargar Apache
sudo systemctl reload apache2
```

### Paso 14: Configurar FreeRADIUS con MySQL

```bash
# Habilitar módulo SQL
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql

# Editar configuración SQL
sudo nano /etc/freeradius/3.0/mods-available/sql
```

Busca y modifica las siguientes líneas:

```
driver = "rlm_sql_mysql"
dialect = "mysql"

mysql {
    tls {
        ...
    }
}

server = "localhost"
port = 3306
login = "radiususer"
password = "TU_PASSWORD_SEGURA"
radius_db = "radius"
```

Guarda y cierra.

```bash
# Reiniciar FreeRADIUS
sudo systemctl restart freeradius
```

### Paso 15: Configurar Firewall (Opcional)

```bash
# Si usas UFW
sudo ufw allow 80/tcp
sudo ufw allow 1812/udp
sudo ufw allow 1813/udp
sudo ufw enable
```

### Paso 16: Verificar instalación

```bash
# Verificar Apache
sudo systemctl status apache2

# Verificar MariaDB
sudo systemctl status mariadb

# Verificar FreeRADIUS
sudo systemctl status freeradius

# Ver logs de Apache
sudo tail -f /var/log/apache2/radius-error.log
```

### Paso 17: Acceder al sistema

1. Abre tu navegador
2. Navega a: `http://TU_IP/radius/`
3. Ingresa tu API Key
4. ¡Listo!

---

## 🔒 Configuración de Seguridad Adicional

### SSL/TLS con Let's Encrypt (RECOMENDADO para producción)

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-apache

# Obtener certificado (reemplaza tu-dominio.com)
sudo certbot --apache -d tu-dominio.com

# El certificado se renovará automáticamente
```

Después de obtener el certificado, actualiza `app.js`:
```javascript
const API_URL = 'https://tu-dominio.com/radius/radius-api.php';
```

### Restringir acceso por IP

Edita `/etc/apache2/sites-available/radius.conf`:

```apache
<Files "radius-api.php">
    Order Allow,Deny
    Allow from 192.168.1.0/24  # Tu red local
    Allow from TU_IP_PUBLICA    # Tu IP pública
</Files>
```

```bash
sudo systemctl reload apache2
```

### Configurar fail2ban (protección contra ataques)

```bash
sudo apt install -y fail2ban

# Crear regla para Apache
sudo nano /etc/fail2ban/jail.local
```

Contenido:
```ini
[apache-radius]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/radius-error.log
maxretry = 5
bantime = 3600
```

```bash
sudo systemctl restart fail2ban
```

---

## 🧪 Verificación y Pruebas

### Probar conexión a la base de datos

```bash
mysql -u radiususer -p radius -e "SELECT COUNT(*) as total_users FROM radcheck;"
```

### Probar autenticación RADIUS

```bash
# Primero, crea un usuario de prueba desde la interfaz web
# Luego prueba:
radtest usuario@fibra password localhost 0 testing123
```

### Probar la API

```bash
# Obtener estadísticas
curl -X GET "http://localhost/radius/radius-api.php/stats" \
  -H "Authorization: Bearer TU_API_KEY"
```

### Ver logs en tiempo real

```bash
# Logs de Apache
sudo tail -f /var/log/apache2/radius-error.log

# Logs de FreeRADIUS
sudo tail -f /var/log/freeradius/radius.log

# Logs de MySQL (si hay problemas)
sudo tail -f /var/log/mysql/error.log
```

---

## 🛠️ Mantenimiento

### Backup de la base de datos

```bash
# Crear backup
mysqldump -u root -p radius > radius_backup_$(date +%Y%m%d).sql

# Comprimir
gzip radius_backup_$(date +%Y%m%d).sql
```

### Restaurar backup

```bash
# Descomprimir
gunzip radius_backup_20240101.sql.gz

# Restaurar
mysql -u root -p radius < radius_backup_20240101.sql
```

### Actualizar el sistema

```bash
# Actualizar paquetes
sudo apt update
sudo apt upgrade -y

# Reiniciar servicios si es necesario
sudo systemctl restart apache2
sudo systemctl restart mariadb
sudo systemctl restart freeradius
```

### Limpiar sesiones antiguas

```bash
mysql -u root -p radius -e "CALL cleanup_old_sessions(90);"
```

---

## ❓ Problemas Comunes

### Error: "No se puede conectar a la base de datos"

**Solución:**
1. Verifica que MariaDB esté corriendo: `sudo systemctl status mariadb`
2. Verifica las credenciales en `radius-api.php`
3. Prueba la conexión: `mysql -u radiususer -p radius`

### Error: "API Key inválida"

**Solución:**
1. Verifica que estés usando la API Key correcta
2. Limpia el cache del navegador (Ctrl+Shift+Del)
3. Verifica que `radius-api.php` tenga la misma API Key configurada

### Error: "Permission denied" al escribir webhooks

**Solución:**
```bash
sudo chmod 666 /var/www/html/radius/webhooks.json
sudo chown www-data:www-data /var/www/html/radius/webhooks.json
```

### FreeRADIUS no autentica usuarios

**Solución:**
1. Verifica que el módulo SQL esté habilitado:
```bash
ls -la /etc/freeradius/3.0/mods-enabled/sql
```

2. Verifica los logs:
```bash
sudo tail -f /var/log/freeradius/radius.log
```

3. Reinicia FreeRADIUS:
```bash
sudo systemctl restart freeradius
```

### Apache no muestra la página

**Solución:**
1. Verifica que Apache esté corriendo:
```bash
sudo systemctl status apache2
```

2. Verifica los permisos:
```bash
sudo chown -R www-data:www-data /var/www/html/radius
```

3. Verifica los logs:
```bash
sudo tail -f /var/log/apache2/error.log
```

---

## 📞 Soporte

- **GitHub Issues**: https://github.com/SV-Com/RADIUS/issues
- **Documentación FreeRADIUS**: https://freeradius.org/documentation/
- **Wiki FreeRADIUS**: https://wiki.freeradius.org/

---

## 📝 Checklist Post-Instalación

- [ ] Apache2 corriendo correctamente
- [ ] PHP funcionando (verifica con `php -v`)
- [ ] MariaDB corriendo y accesible
- [ ] FreeRADIUS corriendo
- [ ] Base de datos creada e importada
- [ ] Archivos web copiados y con permisos correctos
- [ ] API configurada con credenciales correctas
- [ ] Frontend apuntando a la URL correcta
- [ ] Webhooks.json con permisos de escritura
- [ ] VirtualHost configurado y habilitado
- [ ] Firewall configurado (si aplica)
- [ ] SSL/TLS configurado (recomendado)
- [ ] Backup configurado
- [ ] Probado crear un usuario
- [ ] Probado exportar CSV
- [ ] Verificado historial de conexiones

---

¡Instalación completada! 🎉
