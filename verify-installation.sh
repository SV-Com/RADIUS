#!/bin/bash
#
# Script de Verificación Post-Instalación
# Sistema de Gestión Web para FreeRADIUS v2.0
#
# Uso: bash verify-installation.sh
#

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
PASSED=0
FAILED=0
WARNING=0

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_check() {
    echo -ne "  Verificando $1... "
}

print_ok() {
    echo -e "${GREEN}✓ OK${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    if [ -n "$1" ]; then
        echo -e "    ${RED}→ $1${NC}"
    fi
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}! ADVERTENCIA${NC}"
    if [ -n "$1" ]; then
        echo -e "    ${YELLOW}→ $1${NC}"
    fi
    ((WARNING++))
}

print_info() {
    echo -e "    ${BLUE}→ $1${NC}"
}

print_header "Verificación del Sistema RADIUS v2.0"
echo -e "${BLUE}Fecha: $(date)${NC}"

# ==================== VERIFICACIÓN DE SERVICIOS ====================

print_header "1. Servicios del Sistema"

# Apache2
print_check "Apache2"
if systemctl is-active --quiet apache2; then
    print_ok
    APACHE_VERSION=$(apache2 -v | head -n 1 | awk '{print $3}')
    print_info "Versión: $APACHE_VERSION"
else
    print_fail "Apache2 no está corriendo"
    print_info "Ejecuta: sudo systemctl start apache2"
fi

# MariaDB/MySQL
print_check "MariaDB/MySQL"
if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
    print_ok
    if command -v mysql &> /dev/null; then
        MYSQL_VERSION=$(mysql --version | awk '{print $5}' | sed 's/,//')
        print_info "Versión: $MYSQL_VERSION"
    fi
else
    print_fail "MariaDB/MySQL no está corriendo"
    print_info "Ejecuta: sudo systemctl start mariadb"
fi

# FreeRADIUS
print_check "FreeRADIUS"
if systemctl is-active --quiet freeradius; then
    print_ok
    RADIUS_VERSION=$(freeradius -v 2>&1 | head -n 1 | awk '{print $2}')
    print_info "Versión: $RADIUS_VERSION"
else
    print_fail "FreeRADIUS no está corriendo"
    print_info "Ejecuta: sudo systemctl start freeradius"
fi

# PHP
print_check "PHP"
if command -v php &> /dev/null; then
    print_ok
    PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}')
    print_info "Versión: $PHP_VERSION"
else
    print_fail "PHP no está instalado"
fi

# ==================== VERIFICACIÓN DE MÓDULOS PHP ====================

print_header "2. Extensiones PHP"

PHP_MODULES=("mysqli" "pdo_mysql" "json" "mbstring" "curl")

for module in "${PHP_MODULES[@]}"; do
    print_check "$module"
    if php -m | grep -q "$module"; then
        print_ok
    else
        print_fail "Módulo PHP '$module' no encontrado"
        print_info "Instala con: sudo apt install php-${module}"
    fi
done

# ==================== VERIFICACIÓN DE ARCHIVOS ====================

print_header "3. Archivos del Proyecto"

WEB_DIRS=(
    "/var/www/html/radius"
    "/var/www/html"
)

WEB_DIR=""
for dir in "${WEB_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/radius-api.php" ]; then
        WEB_DIR="$dir"
        break
    fi
done

if [ -z "$WEB_DIR" ]; then
    print_check "Directorio del proyecto"
    print_fail "No se encontró el directorio del proyecto"
    print_info "Debe estar en /var/www/html/radius/ o /var/www/html/"
else
    print_check "Directorio del proyecto"
    print_ok
    print_info "Ubicación: $WEB_DIR"

    FILES=("radius-api.php" "index.html" "app.js" "styles.css" "webhooks.json")

    for file in "${FILES[@]}"; do
        print_check "$file"
        if [ -f "$WEB_DIR/$file" ]; then
            print_ok

            # Verificar permisos
            PERMS=$(stat -c "%a" "$WEB_DIR/$file" 2>/dev/null || stat -f "%Lp" "$WEB_DIR/$file" 2>/dev/null)
            if [ "$file" = "webhooks.json" ]; then
                if [ "$PERMS" = "666" ] || [ "$PERMS" = "664" ]; then
                    print_info "Permisos: $PERMS (correcto)"
                else
                    print_warn "Permisos: $PERMS (debería ser 666)"
                    print_info "Ejecuta: sudo chmod 666 $WEB_DIR/webhooks.json"
                fi
            fi
        else
            print_fail "Archivo no encontrado: $WEB_DIR/$file"
        fi
    done
fi

# ==================== VERIFICACIÓN DE BASE DE DATOS ====================

print_header "4. Base de Datos"

print_check "Conexión a MySQL"
if command -v mysql &> /dev/null; then
    # Intentar conectar como root
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        print_ok

        # Buscar base de datos radius
        print_check "Base de datos 'radius'"
        if mysql -u root -e "USE radius; SELECT 1" &>/dev/null; then
            print_ok

            # Verificar tablas principales
            TABLES=("radcheck" "radreply" "radacct" "radgroupcheck" "radgroupreply" "radusergroup")

            for table in "${TABLES[@]}"; do
                print_check "Tabla '$table'"
                if mysql -u root radius -e "DESCRIBE $table" &>/dev/null; then
                    print_ok

                    # Contar registros
                    if [ "$table" = "radcheck" ]; then
                        COUNT=$(mysql -u root radius -e "SELECT COUNT(*) FROM $table WHERE attribute='Cleartext-Password'" -sN)
                        print_info "Usuarios: $COUNT"
                    fi
                else
                    print_fail "Tabla no existe"
                fi
            done

            # Verificar tablas v2.0
            print_check "Tabla 'api_users' (v2.0)"
            if mysql -u root radius -e "DESCRIBE api_users" &>/dev/null; then
                print_ok
            else
                print_warn "Tabla no existe - ejecuta migration_v2.sql"
            fi

            print_check "Tabla 'audit_log' (v2.0)"
            if mysql -u root radius -e "DESCRIBE audit_log" &>/dev/null; then
                print_ok
            else
                print_warn "Tabla no existe - ejecuta migration_v2.sql"
            fi

        else
            print_fail "Base de datos 'radius' no existe"
            print_info "Crea la base de datos y ejecuta el schema.sql de FreeRADIUS"
        fi
    else
        print_warn "No se puede conectar como root sin contraseña"
        print_info "Necesitarás las credenciales para verificar la BD"
    fi
else
    print_fail "Cliente MySQL no encontrado"
fi

# ==================== VERIFICACIÓN DE CONFIGURACIÓN ====================

print_header "5. Configuración"

if [ -n "$WEB_DIR" ] && [ -f "$WEB_DIR/radius-api.php" ]; then
    # Verificar configuración de DB
    print_check "Configuración de DB en API"
    DB_HOST=$(grep "define('DB_HOST'" "$WEB_DIR/radius-api.php" | cut -d "'" -f 4)
    DB_NAME=$(grep "define('DB_NAME'" "$WEB_DIR/radius-api.php" | cut -d "'" -f 4)
    DB_USER=$(grep "define('DB_USER'" "$WEB_DIR/radius-api.php" | cut -d "'" -f 4)

    if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
        print_ok
        print_info "Host: $DB_HOST"
        print_info "Database: $DB_NAME"
        print_info "User: $DB_USER"
    else
        print_fail "Configuración incompleta"
    fi

    # Verificar API Key
    print_check "API Key configurada"
    API_KEY=$(grep "define('API_KEY'" "$WEB_DIR/radius-api.php" | cut -d "'" -f 4)

    if [ "$API_KEY" = "tu_api_key_secreta_aqui" ] || [ "$API_KEY" = "your_api_key_here" ]; then
        print_warn "API Key no ha sido cambiada"
        print_info "Genera una con: openssl rand -hex 32"
    elif [ -n "$API_KEY" ]; then
        print_ok
        print_info "Longitud: ${#API_KEY} caracteres"
    else
        print_fail "API Key no configurada"
    fi

    # Verificar URL en app.js
    print_check "URL configurada en frontend"
    if [ -f "$WEB_DIR/app.js" ]; then
        API_URL=$(grep "const API_URL" "$WEB_DIR/app.js" | cut -d "'" -f 2)

        if [ "$API_URL" = "http://TU_SERVIDOR/radius-api.php" ]; then
            print_warn "URL no ha sido configurada"
            print_info "Edita app.js y cambia TU_SERVIDOR por la IP del servidor"
        elif [ -n "$API_URL" ]; then
            print_ok
            print_info "URL: $API_URL"
        else
            print_fail "URL no encontrada"
        fi
    fi
fi

# Verificar configuración de FreeRADIUS SQL
print_check "Módulo SQL de FreeRADIUS"
if [ -L /etc/freeradius/3.0/mods-enabled/sql ]; then
    print_ok
else
    print_fail "Módulo SQL no habilitado"
    print_info "Ejecuta: sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql"
fi

# ==================== VERIFICACIÓN DE RED ====================

print_header "6. Conectividad"

# Obtener IP
SERVER_IP=$(hostname -I | awk '{print $1}')
print_check "IP del servidor"
if [ -n "$SERVER_IP" ]; then
    print_ok
    print_info "IP: $SERVER_IP"
else
    print_warn "No se pudo detectar la IP"
fi

# Verificar puerto 80
print_check "Puerto 80 (HTTP)"
if ss -tuln | grep -q ":80 "; then
    print_ok
else
    print_warn "Puerto 80 no está escuchando"
    print_info "Verifica que Apache esté corriendo"
fi

# Verificar puertos RADIUS
print_check "Puerto 1812 (RADIUS Auth)"
if ss -tuln | grep -q ":1812 "; then
    print_ok
else
    print_warn "Puerto 1812 no está escuchando"
    print_info "FreeRADIUS podría no estar configurado correctamente"
fi

print_check "Puerto 1813 (RADIUS Acct)"
if ss -tuln | grep -q ":1813 "; then
    print_ok
else
    print_warn "Puerto 1813 no está escuchando"
    print_info "FreeRADIUS podría no estar configurado correctamente"
fi

# ==================== PRUEBA DE CONECTIVIDAD API ====================

print_header "7. Prueba de API"

if [ -n "$SERVER_IP" ] && [ -n "$WEB_DIR" ]; then
    print_check "Respuesta HTTP de la API"

    # Probar con localhost primero
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/radius/radius-api.php/stats" -H "Authorization: Bearer test" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "401" ]; then
        print_ok
        print_info "La API responde correctamente (401 Unauthorized esperado)"
    elif [ "$HTTP_CODE" = "000" ]; then
        print_warn "No se pudo conectar a la API"
        print_info "Verifica que Apache esté corriendo y la ruta sea correcta"
    else
        print_warn "Código HTTP: $HTTP_CODE"
    fi
fi

# ==================== RESUMEN ====================

print_header "Resumen de Verificación"

echo ""
echo -e "  ${GREEN}✓ Pasadas:${NC}      $PASSED"
echo -e "  ${YELLOW}! Advertencias:${NC} $WARNING"
echo -e "  ${RED}✗ Fallidas:${NC}     $FAILED"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNING -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}¡Instalación completamente verificada!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Accede al sistema en: ${GREEN}http://$SERVER_IP/radius/${NC}"
    echo ""
elif [ $FAILED -eq 0 ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Instalación verificada con advertencias${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "El sistema debería funcionar, pero revisa las advertencias arriba."
    echo ""
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Se encontraron problemas${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "Revisa los errores arriba y corrígelos antes de continuar."
    echo ""
fi

# ==================== INFORMACIÓN ADICIONAL ====================

print_header "Comandos Útiles"

echo ""
echo "  Ver logs de Apache:"
echo "    sudo tail -f /var/log/apache2/error.log"
echo ""
echo "  Ver logs de FreeRADIUS:"
echo "    sudo tail -f /var/log/freeradius/radius.log"
echo ""
echo "  Reiniciar servicios:"
echo "    sudo systemctl restart apache2"
echo "    sudo systemctl restart mariadb"
echo "    sudo systemctl restart freeradius"
echo ""
echo "  Probar autenticación RADIUS:"
echo "    radtest usuario password localhost 0 testing123"
echo ""
echo "  Verificar base de datos:"
echo "    mysql -u root -p radius"
echo ""

exit 0
