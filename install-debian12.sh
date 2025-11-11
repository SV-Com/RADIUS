#!/bin/bash
#
# Script de Instalación Automática
# Sistema de Gestión Web para FreeRADIUS v2.0
# Compatible con: Debian 12, Ubuntu 22.04+
#
# Uso: sudo bash install-debian12.sh
#

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (usa sudo)"
   exit 1
fi

print_info "=========================================="
print_info "Instalación Sistema RADIUS Web Manager v2.0"
print_info "=========================================="
echo ""

# Detectar sistema operativo
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    print_info "Sistema detectado: $OS $VER"
else
    print_error "No se puede detectar el sistema operativo"
    exit 1
fi

# Actualizar sistema
print_info "Actualizando repositorios del sistema..."
apt-get update -qq

# Instalar dependencias básicas
print_info "Instalando dependencias básicas..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    software-properties-common \
    ca-certificates \
    lsb-release \
    apt-transport-https

print_success "Dependencias básicas instaladas"

# Instalar Apache2
print_info "Instalando Apache2..."
apt-get install -y -qq apache2

# Habilitar módulos necesarios de Apache
a2enmod rewrite
a2enmod headers
a2enmod ssl

systemctl enable apache2
systemctl restart apache2

print_success "Apache2 instalado y configurado"

# Instalar PHP 8.2
print_info "Instalando PHP 8.2 y extensiones..."
apt-get install -y -qq \
    php \
    php-cli \
    php-fpm \
    php-mysql \
    php-pdo \
    php-mbstring \
    php-curl \
    php-xml \
    php-zip \
    php-gd \
    php-json \
    libapache2-mod-php

# Reiniciar Apache para cargar PHP
systemctl restart apache2

print_success "PHP instalado y configurado"

# Verificar versión de PHP
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
print_info "Versión de PHP instalada: $PHP_VERSION"

# Instalar MariaDB/MySQL
print_info "Instalando MariaDB Server..."
apt-get install -y -qq mariadb-server mariadb-client

# Habilitar y arrancar MariaDB
systemctl enable mariadb
systemctl start mariadb

print_success "MariaDB instalado"

# Instalar FreeRADIUS y dependencias
print_info "Instalando FreeRADIUS..."
apt-get install -y -qq \
    freeradius \
    freeradius-mysql \
    freeradius-utils

print_success "FreeRADIUS instalado"

# Crear directorio de trabajo temporal
WORK_DIR="/tmp/radius-install"
mkdir -p $WORK_DIR

# Pedir configuraciones al usuario
echo ""
print_info "=========================================="
print_info "Configuración de la Base de Datos"
print_info "=========================================="
echo ""

read -p "¿Deseas crear una nueva base de datos? (s/n): " CREATE_DB

if [[ $CREATE_DB =~ ^[Ss]$ ]]; then
    read -p "Nombre de la base de datos [radius]: " DB_NAME
    DB_NAME=${DB_NAME:-radius}

    read -p "Usuario de la base de datos [radiususer]: " DB_USER
    DB_USER=${DB_USER:-radiususer}

    read -sp "Contraseña para el usuario de BD: " DB_PASS
    echo ""

    if [ -z "$DB_PASS" ]; then
        print_error "La contraseña no puede estar vacía"
        exit 1
    fi

    # Crear base de datos y usuario
    print_info "Creando base de datos '$DB_NAME'..."

    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

    print_success "Base de datos creada"

    # Importar esquema de FreeRADIUS
    print_info "Importando esquema de FreeRADIUS..."
    if [ -f /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql ]; then
        mysql -u root $DB_NAME < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
        print_success "Esquema de FreeRADIUS importado"
    else
        print_warning "No se encontró el archivo de esquema de FreeRADIUS"
    fi
else
    read -p "Host de la base de datos [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}

    read -p "Nombre de la base de datos: " DB_NAME
    read -p "Usuario de la base de datos: " DB_USER
    read -sp "Contraseña del usuario: " DB_PASS
    echo ""
fi

# Generar API Key aleatoria
API_KEY=$(openssl rand -hex 32)
print_info "API Key generada: $API_KEY"

# Configurar directorio web
WEB_DIR="/var/www/html/radius"
print_info "Creando directorio web en $WEB_DIR..."
mkdir -p $WEB_DIR

# Descargar archivos del proyecto desde GitHub
print_info "Descargando archivos del proyecto..."
cd $WORK_DIR

if [ -d "RADIUS" ]; then
    rm -rf RADIUS
fi

git clone -q https://github.com/SV-Com/RADIUS.git

if [ ! -d "RADIUS" ]; then
    print_error "Error al descargar el proyecto desde GitHub"
    exit 1
fi

# Copiar archivos al directorio web
print_info "Copiando archivos al servidor web..."
cp RADIUS/radius-api.php $WEB_DIR/
cp RADIUS/app.js $WEB_DIR/
cp RADIUS/styles.css $WEB_DIR/
cp RADIUS/index-v2.html $WEB_DIR/index.html

# Crear archivo webhooks.json
touch $WEB_DIR/webhooks.json
chmod 666 $WEB_DIR/webhooks.json

print_success "Archivos copiados"

# Configurar radius-api.php con las credenciales
print_info "Configurando API con credenciales de base de datos..."

cat > $WEB_DIR/radius-api.php.tmp <<EOF
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if (\$_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Configuración de la base de datos
define('DB_HOST', '${DB_HOST:-localhost}');
define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER');
define('DB_PASS', '$DB_PASS');

// Autenticación
define('API_KEY', '$API_KEY');

// Configuración de email (configura según tus necesidades)
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);
define('SMTP_USER', 'tu_email@gmail.com');
define('SMTP_PASS', 'tu_password');
define('SMTP_FROM', 'tu_email@gmail.com');
define('SMTP_FROM_NAME', 'Sistema RADIUS');

// Configuración de webhooks
define('WEBHOOKS_ENABLED', true);
define('WEBHOOKS_FILE', __DIR__ . '/webhooks.json');
EOF

# Agregar el resto del código PHP desde el archivo original
tail -n +31 RADIUS/radius-api.php >> $WEB_DIR/radius-api.php.tmp
mv $WEB_DIR/radius-api.php.tmp $WEB_DIR/radius-api.php

print_success "API configurada"

# Obtener la IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}')

# Configurar app.js con la URL correcta
print_info "Configurando frontend..."
sed -i "s|http://TU_SERVIDOR/radius-api.php|http://$SERVER_IP/radius/radius-api.php|g" $WEB_DIR/app.js

print_success "Frontend configurado"

# Configurar permisos
print_info "Configurando permisos..."
chown -R www-data:www-data $WEB_DIR
chmod -R 755 $WEB_DIR
chmod 666 $WEB_DIR/webhooks.json

print_success "Permisos configurados"

# Importar migration v2
if [ -f "RADIUS/migration_v2.sql" ]; then
    print_info "Importando tablas adicionales (migration_v2.sql)..."
    mysql -u root $DB_NAME < RADIUS/migration_v2.sql 2>/dev/null || true
    print_success "Tablas adicionales importadas"
fi

# Crear configuración de Apache para el sitio
print_info "Configurando VirtualHost de Apache..."

cat > /etc/apache2/sites-available/radius.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $WEB_DIR

    <Directory $WEB_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        # Seguridad adicional
        <Files "radius-api.php">
            # Permitir acceso desde cualquier IP
            # Para restringir, descomenta las siguientes líneas:
            # Order Allow,Deny
            # Allow from 192.168.1.0/24
        </Files>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/radius-error.log
    CustomLog \${APACHE_LOG_DIR}/radius-access.log combined
</VirtualHost>
EOF

# Deshabilitar sitio por defecto y habilitar el nuestro
a2dissite 000-default.conf 2>/dev/null || true
a2ensite radius.conf

# Recargar Apache
systemctl reload apache2

print_success "VirtualHost configurado"

# Configurar FreeRADIUS para usar MySQL
print_info "Configurando FreeRADIUS para usar MySQL..."

# Habilitar módulo SQL en FreeRADIUS
if [ ! -L /etc/freeradius/3.0/mods-enabled/sql ]; then
    ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
fi

# Configurar conexión SQL en FreeRADIUS
SQL_CONF="/etc/freeradius/3.0/mods-available/sql"
if [ -f "$SQL_CONF" ]; then
    sed -i "s/driver = \"rlm_sql_null\"/driver = \"rlm_sql_mysql\"/g" $SQL_CONF
    sed -i "s/dialect = \"sqlite\"/dialect = \"mysql\"/g" $SQL_CONF
    sed -i "s/server = \"localhost\"/server = \"${DB_HOST:-localhost}\"/g" $SQL_CONF
    sed -i "s/port = 3306/port = 3306/g" $SQL_CONF
    sed -i "s/login = \"radius\"/login = \"$DB_USER\"/g" $SQL_CONF
    sed -i "s/password = \"radpass\"/password = \"$DB_PASS\"/g" $SQL_CONF
    sed -i "s/radius_db = \"radius\"/radius_db = \"$DB_NAME\"/g" $SQL_CONF
fi

# Reiniciar FreeRADIUS
systemctl restart freeradius
systemctl enable freeradius

print_success "FreeRADIUS configurado"

# Configurar firewall si ufw está instalado
if command -v ufw &> /dev/null; then
    print_info "Configurando firewall (UFW)..."
    ufw allow 80/tcp comment 'HTTP for RADIUS Web' 2>/dev/null || true
    ufw allow 1812/udp comment 'RADIUS Authentication' 2>/dev/null || true
    ufw allow 1813/udp comment 'RADIUS Accounting' 2>/dev/null || true
    print_success "Firewall configurado"
fi

# Limpiar archivos temporales
rm -rf $WORK_DIR

# Crear archivo de información de instalación
INFO_FILE="$WEB_DIR/INSTALLATION_INFO.txt"
cat > $INFO_FILE <<EOF
========================================
RADIUS Web Manager v2.0 - Información de Instalación
========================================

Fecha de instalación: $(date)
Sistema: $OS $VER

ACCESO AL SISTEMA:
------------------
URL: http://$SERVER_IP/radius/
API URL: http://$SERVER_IP/radius/radius-api.php

CREDENCIALES:
-------------
API Key: $API_KEY

BASE DE DATOS:
--------------
Host: ${DB_HOST:-localhost}
Database: $DB_NAME
Usuario: $DB_USER
Contraseña: $DB_PASS

UBICACIONES:
------------
Directorio Web: $WEB_DIR
Logs Apache: /var/log/apache2/radius-*.log
Config FreeRADIUS: /etc/freeradius/3.0/

SERVICIOS:
----------
Apache2: systemctl status apache2
MariaDB: systemctl status mariadb
FreeRADIUS: systemctl status freeradius

COMANDOS ÚTILES:
----------------
# Ver logs de Apache
tail -f /var/log/apache2/radius-error.log

# Ver logs de FreeRADIUS
tail -f /var/log/freeradius/radius.log

# Probar autenticación RADIUS
radtest usuario password localhost 0 testing123

# Backup de base de datos
mysqldump -u root $DB_NAME > radius_backup_\$(date +%Y%m%d).sql

SEGURIDAD:
----------
1. Guarda este archivo en un lugar seguro
2. Cambia las credenciales de email SMTP en radius-api.php
3. Considera usar HTTPS en producción
4. Restringe el acceso a la API por IP si es necesario

========================================
EOF

chmod 600 $INFO_FILE

print_success "=========================================="
print_success "¡INSTALACIÓN COMPLETADA!"
print_success "=========================================="
echo ""
print_info "URL de acceso: ${GREEN}http://$SERVER_IP/radius/${NC}"
print_info "API Key: ${YELLOW}$API_KEY${NC}"
echo ""
print_warning "IMPORTANTE: Guarda tu API Key, la necesitarás para acceder"
print_info "Información completa guardada en: $INFO_FILE"
echo ""
print_info "Servicios instalados:"
print_success "  ✓ Apache2"
print_success "  ✓ PHP $PHP_VERSION"
print_success "  ✓ MariaDB"
print_success "  ✓ FreeRADIUS"
print_success "  ✓ RADIUS Web Manager v2.0"
echo ""
print_info "Para ver el estado de los servicios:"
echo "  sudo systemctl status apache2"
echo "  sudo systemctl status mariadb"
echo "  sudo systemctl status freeradius"
echo ""
print_info "Para ver los logs:"
echo "  sudo tail -f /var/log/apache2/radius-error.log"
echo ""
print_success "¡Disfruta de tu nuevo sistema RADIUS Web Manager!"
echo ""
