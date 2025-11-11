-- =====================================================
-- Migration Script para RADIUS v2.0
-- Nuevas tablas para roles, permisos y webhooks
-- =====================================================

-- Tabla para usuarios de la API con roles
CREATE TABLE IF NOT EXISTS `api_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL,
  `api_key` varchar(255) NOT NULL,
  `role` enum('viewer','operator','admin') DEFAULT 'viewer',
  `email` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_login` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `api_key` (`api_key`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla para registro de eventos (audit log)
CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `event_type` varchar(50) NOT NULL,
  `username` varchar(64) DEFAULT NULL,
  `performed_by` varchar(64) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `details` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_username` (`username`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla para configuración de notificaciones por email
CREATE TABLE IF NOT EXISTS `email_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `event_type` varchar(50) NOT NULL,
  `recipient_email` varchar(255) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_event_type` (`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Índices adicionales para optimizar consultas de historial
ALTER TABLE `radacct`
ADD INDEX IF NOT EXISTS `idx_username_starttime` (`username`, `acctstarttime`),
ADD INDEX IF NOT EXISTS `idx_stoptime` (`acctstoptime`);

-- Vista para estadísticas rápidas de usuarios
CREATE OR REPLACE VIEW `user_stats` AS
SELECT
    rc.username,
    ui.creationdate,
    COUNT(DISTINCT ra.radacctid) as total_sessions,
    SUM(ra.acctsessiontime) as total_session_time,
    SUM(ra.acctinputoctets) as total_upload_bytes,
    SUM(ra.acctoutputoctets) as total_download_bytes,
    MAX(ra.acctstarttime) as last_connection,
    (SELECT COUNT(*) FROM radacct WHERE username = rc.username AND acctstoptime IS NULL) as active_sessions
FROM radcheck rc
LEFT JOIN userinfo ui ON rc.username = ui.username
LEFT JOIN radacct ra ON rc.username = ra.username
WHERE rc.attribute = 'Cleartext-Password'
GROUP BY rc.username;

-- Insertar usuario admin por defecto (cambiar el api_key por uno seguro)
INSERT INTO `api_users` (`username`, `api_key`, `role`, `email`)
VALUES ('admin', 'tu_api_key_secreta_aqui', 'admin', 'admin@example.com')
ON DUPLICATE KEY UPDATE `api_key` = `api_key`;

-- Ejemplos de notificaciones por email (opcional)
-- INSERT INTO `email_notifications` (`event_type`, `recipient_email`)
-- VALUES
-- ('user.created', 'admin@example.com'),
-- ('user.deleted', 'admin@example.com');

-- =====================================================
-- Procedimientos almacenados útiles
-- =====================================================

-- Procedimiento para limpiar sesiones antiguas
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `cleanup_old_sessions`(IN days_to_keep INT)
BEGIN
    DELETE FROM radacct
    WHERE acctstoptime IS NOT NULL
    AND acctstoptime < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);

    SELECT ROW_COUNT() as deleted_records;
END$$
DELIMITER ;

-- Procedimiento para obtener top usuarios por consumo
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `get_top_bandwidth_users`(IN limit_count INT, IN days_back INT)
BEGIN
    SELECT
        username,
        SUM(acctinputoctets + acctoutputoctets) as total_bandwidth,
        SUM(acctinputoctets) as total_upload,
        SUM(acctoutputoctets) as total_download,
        COUNT(*) as session_count
    FROM radacct
    WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL days_back DAY)
    GROUP BY username
    ORDER BY total_bandwidth DESC
    LIMIT limit_count;
END$$
DELIMITER ;

-- Función para formatear bytes a formato legible
DELIMITER $$
CREATE FUNCTION IF NOT EXISTS `format_bytes`(bytes BIGINT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE result VARCHAR(20);

    IF bytes IS NULL THEN
        RETURN '0 B';
    ELSEIF bytes < 1024 THEN
        SET result = CONCAT(bytes, ' B');
    ELSEIF bytes < 1048576 THEN
        SET result = CONCAT(ROUND(bytes / 1024, 2), ' KB');
    ELSEIF bytes < 1073741824 THEN
        SET result = CONCAT(ROUND(bytes / 1048576, 2), ' MB');
    ELSE
        SET result = CONCAT(ROUND(bytes / 1073741824, 2), ' GB');
    END IF;

    RETURN result;
END$$
DELIMITER ;

-- =====================================================
-- Triggers para audit log
-- =====================================================

-- Trigger cuando se crea un usuario
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS `after_user_insert`
AFTER INSERT ON `radcheck`
FOR EACH ROW
BEGIN
    IF NEW.attribute = 'Cleartext-Password' THEN
        INSERT INTO audit_log (event_type, username, performed_by, details)
        VALUES ('user.created', NEW.username, 'API', CONCAT('Usuario creado: ', NEW.username));
    END IF;
END$$
DELIMITER ;

-- Trigger cuando se elimina un usuario
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS `after_user_delete`
AFTER DELETE ON `radcheck`
FOR EACH ROW
BEGIN
    IF OLD.attribute = 'Cleartext-Password' THEN
        INSERT INTO audit_log (event_type, username, performed_by, details)
        VALUES ('user.deleted', OLD.username, 'API', CONCAT('Usuario eliminado: ', OLD.username));
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- Datos de ejemplo (opcional - comentado)
-- =====================================================

-- Crear algunos usuarios de prueba
-- CALL crear_usuario_pppoe('test1@fibra', 'password123', '50M', '50M', 'premium');
-- CALL crear_usuario_pppoe('test2@fibra', 'password456', '100M', '100M', 'premium');

COMMIT;

-- =====================================================
-- Verificar instalación
-- =====================================================
SELECT 'Migration v2.0 completed successfully!' as status;

-- Mostrar resumen de tablas
SELECT
    TABLE_NAME as 'Tabla',
    TABLE_ROWS as 'Filas',
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as 'Tamaño (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME IN ('api_users', 'audit_log', 'email_notifications', 'radcheck', 'radacct', 'radreply', 'userinfo')
ORDER BY TABLE_NAME;
