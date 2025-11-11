-- Scripts SQL útiles para FreeRADIUS/DaloRADIUS
-- Ejecutar estos scripts en MySQL para verificar y gestionar usuarios

-- ============================================
-- CONSULTAS DE VERIFICACIÓN
-- ============================================

-- Ver todos los usuarios con sus contraseñas
SELECT 
    username,
    value as password
FROM radcheck 
WHERE attribute = 'Cleartext-Password'
ORDER BY username;

-- Ver usuarios con sus velocidades configuradas
SELECT 
    rc.username,
    rc.value as password,
    MAX(CASE WHEN rr.attribute = 'Huawei-Input-Average-Rate' THEN rr.value END) as upload_speed,
    MAX(CASE WHEN rr.attribute = 'Huawei-Output-Average-Rate' THEN rr.value END) as download_speed
FROM radcheck rc
LEFT JOIN radreply rr ON rc.username = rr.username
WHERE rc.attribute = 'Cleartext-Password'
GROUP BY rc.username, rc.value
ORDER BY rc.username;

-- Ver usuarios con sus grupos/perfiles
SELECT 
    rc.username,
    rg.groupname as profile,
    rc.value as password
FROM radcheck rc
LEFT JOIN radusergroup rg ON rc.username = rg.username
WHERE rc.attribute = 'Cleartext-Password'
ORDER BY rc.username;

-- Contar total de usuarios
SELECT COUNT(DISTINCT username) as total_usuarios 
FROM radcheck 
WHERE attribute = 'Cleartext-Password';

-- Ver sesiones activas (usuarios conectados actualmente)
SELECT 
    username,
    nasipaddress,
    acctstarttime,
    framedipaddress,
    callingstationid
FROM radacct 
WHERE acctstoptime IS NULL
ORDER BY acctstarttime DESC;

-- Contar sesiones activas
SELECT COUNT(*) as sesiones_activas 
FROM radacct 
WHERE acctstoptime IS NULL;

-- Ver historial de conexiones de un usuario específico (últimas 10)
SELECT 
    username,
    acctstarttime as inicio,
    acctstoptime as fin,
    TIMESTAMPDIFF(MINUTE, acctstarttime, COALESCE(acctstoptime, NOW())) as duracion_minutos,
    acctinputoctets as bytes_recibidos,
    acctoutputoctets as bytes_enviados,
    framedipaddress as ip
FROM radacct 
WHERE username = 'usuario@dominio'
ORDER BY acctstarttime DESC
LIMIT 10;

-- Ver usuarios creados recientemente (últimos 10)
SELECT 
    username,
    creationdate,
    creationby
FROM userinfo
ORDER BY creationdate DESC
LIMIT 10;

-- ============================================
-- OPERACIONES DE MANTENIMIENTO
-- ============================================

-- Crear un usuario manualmente (reemplazar valores)
-- Paso 1: Agregar usuario y contraseña
INSERT INTO radcheck (username, attribute, op, value) 
VALUES ('nuevo_usuario@fibra', 'Cleartext-Password', ':=', 'password123');

-- Paso 2: Agregar velocidad de upload
INSERT INTO radreply (username, attribute, op, value) 
VALUES ('nuevo_usuario@fibra', 'Huawei-Input-Average-Rate', ':=', '50M');

-- Paso 3: Agregar velocidad de download
INSERT INTO radreply (username, attribute, op, value) 
VALUES ('nuevo_usuario@fibra', 'Huawei-Output-Average-Rate', ':=', '50M');

-- Paso 4: Agregar a userinfo
INSERT INTO userinfo (username, creationdate, creationby) 
VALUES ('nuevo_usuario@fibra', NOW(), 'Manual');

-- Actualizar contraseña de un usuario
UPDATE radcheck 
SET value = 'nueva_password' 
WHERE username = 'usuario@dominio' 
AND attribute = 'Cleartext-Password';

-- Actualizar velocidad de upload de un usuario
UPDATE radreply 
SET value = '100M' 
WHERE username = 'usuario@dominio' 
AND attribute = 'Huawei-Input-Average-Rate';

-- Actualizar velocidad de download de un usuario
UPDATE radreply 
SET value = '100M' 
WHERE username = 'usuario@dominio' 
AND attribute = 'Huawei-Output-Average-Rate';

-- Eliminar un usuario completamente
DELETE FROM radcheck WHERE username = 'usuario@dominio';
DELETE FROM radreply WHERE username = 'usuario@dominio';
DELETE FROM radusergroup WHERE username = 'usuario@dominio';
DELETE FROM userinfo WHERE username = 'usuario@dominio';
-- Nota: El historial en radacct se mantiene por razones de auditoría

-- ============================================
-- CONSULTAS AVANZADAS Y REPORTES
-- ============================================

-- Usuarios que nunca se han conectado
SELECT rc.username
FROM radcheck rc
WHERE rc.attribute = 'Cleartext-Password'
AND rc.username NOT IN (SELECT DISTINCT username FROM radacct);

-- Usuarios conectados en las últimas 24 horas
SELECT DISTINCT username, MAX(acctstarttime) as ultima_conexion
FROM radacct
WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY username
ORDER BY ultima_conexion DESC;

-- Top 10 usuarios por tiempo de conexión (último mes)
SELECT 
    username,
    COUNT(*) as num_conexiones,
    SUM(TIMESTAMPDIFF(MINUTE, acctstarttime, COALESCE(acctstoptime, NOW()))) as minutos_totales,
    ROUND(SUM(TIMESTAMPDIFF(MINUTE, acctstarttime, COALESCE(acctstoptime, NOW()))) / 60, 2) as horas_totales
FROM radacct
WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY username
ORDER BY minutos_totales DESC
LIMIT 10;

-- Top 10 usuarios por consumo de datos (último mes)
SELECT 
    username,
    ROUND(SUM(acctinputoctets + acctoutputoctets) / 1024 / 1024 / 1024, 2) as gb_totales,
    ROUND(SUM(acctinputoctets) / 1024 / 1024 / 1024, 2) as gb_descarga,
    ROUND(SUM(acctoutputoctets) / 1024 / 1024 / 1024, 2) as gb_subida
FROM radacct
WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY username
ORDER BY gb_totales DESC
LIMIT 10;

-- Ver todos los atributos RADIUS disponibles en la base de datos
SELECT DISTINCT attribute 
FROM radcheck 
ORDER BY attribute;

SELECT DISTINCT attribute 
FROM radreply 
ORDER BY attribute;

-- Verificar integridad: usuarios sin velocidad configurada
SELECT rc.username
FROM radcheck rc
WHERE rc.attribute = 'Cleartext-Password'
AND rc.username NOT IN (
    SELECT username FROM radreply WHERE attribute = 'Huawei-Input-Average-Rate'
);

-- ============================================
-- LIMPIEZA Y OPTIMIZACIÓN
-- ============================================

-- Limpiar sesiones antiguas (más de 1 año)
-- ADVERTENCIA: Esto eliminará el historial permanentemente
-- DELETE FROM radacct WHERE acctstarttime < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- Optimizar tabla radacct (después de eliminar registros)
-- OPTIMIZE TABLE radacct;

-- Ver tamaño de las tablas
SELECT 
    table_name AS tabla,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS tamaño_mb
FROM information_schema.TABLES
WHERE table_schema = 'radius'
ORDER BY (data_length + index_length) DESC;

-- ============================================
-- BACKUP Y RESTAURACIÓN
-- ============================================

-- Para hacer backup de usuarios (ejecutar en bash):
/*
mysqldump -u radius -p radius radcheck radreply radusergroup userinfo > backup_usuarios.sql
*/

-- Para restaurar el backup:
/*
mysql -u radius -p radius < backup_usuarios.sql
*/

-- ============================================
-- PERFILES/GRUPOS PREDEFINIDOS
-- ============================================

-- Crear un grupo de velocidad (ejemplo: plan 50MB)
INSERT INTO radgroupreply (groupname, attribute, op, value)
VALUES 
    ('plan_50mb', 'Huawei-Input-Average-Rate', ':=', '50M'),
    ('plan_50mb', 'Huawei-Output-Average-Rate', ':=', '50M');

-- Asignar un usuario a un grupo
INSERT INTO radusergroup (username, groupname, priority)
VALUES ('usuario@dominio', 'plan_50mb', 0);

-- Ver todos los grupos disponibles
SELECT DISTINCT groupname FROM radgroupreply;

-- Ver usuarios de un grupo específico
SELECT username, groupname, priority
FROM radusergroup
WHERE groupname = 'plan_50mb'
ORDER BY username;

-- ============================================
-- MONITOREO EN TIEMPO REAL
-- ============================================

-- Monitorear nuevas conexiones (ejecutar repetidamente)
SELECT 
    username,
    nasipaddress,
    acctstarttime,
    framedipaddress
FROM radacct
WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)
AND acctstoptime IS NULL
ORDER BY acctstarttime DESC;

-- Ver estadísticas de hoy
SELECT 
    COUNT(DISTINCT username) as usuarios_unicos,
    COUNT(*) as total_conexiones,
    SUM(TIMESTAMPDIFF(MINUTE, acctstarttime, COALESCE(acctstoptime, NOW()))) as minutos_totales,
    ROUND(SUM(acctinputoctets + acctoutputoctets) / 1024 / 1024 / 1024, 2) as gb_totales
FROM radacct
WHERE DATE(acctstarttime) = CURDATE();

-- ============================================
-- TROUBLESHOOTING
-- ============================================

-- Buscar usuarios duplicados
SELECT username, COUNT(*) as duplicados
FROM radcheck
WHERE attribute = 'Cleartext-Password'
GROUP BY username
HAVING COUNT(*) > 1;

-- Ver usuarios con configuración incompleta
SELECT rc.username
FROM radcheck rc
WHERE rc.attribute = 'Cleartext-Password'
AND (
    rc.username NOT IN (SELECT username FROM radreply WHERE attribute = 'Huawei-Input-Average-Rate')
    OR rc.username NOT IN (SELECT username FROM radreply WHERE attribute = 'Huawei-Output-Average-Rate')
);

-- Verificar conexiones con errores
SELECT 
    username,
    acctterminatecause,
    COUNT(*) as veces
FROM radacct
WHERE acctstoptime >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
AND acctterminatecause != 'User-Request'
GROUP BY username, acctterminatecause
ORDER BY veces DESC;
