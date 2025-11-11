<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Configuración de la base de datos
define('DB_HOST', 'localhost');
define('DB_NAME', 'radius');
define('DB_USER', 'radius');
define('DB_PASS', 'tu_password_mysql');

// Autenticación básica (cambiar estos valores)
define('API_KEY', 'tu_api_key_secreta_aqui');

// Configuración de email (para notificaciones)
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);
define('SMTP_USER', 'tu_email@gmail.com');
define('SMTP_PASS', 'tu_password_email');
define('SMTP_FROM', 'tu_email@gmail.com');
define('SMTP_FROM_NAME', 'Sistema RADIUS');

// Configuración de webhooks
define('WEBHOOKS_ENABLED', true);
define('WEBHOOKS_FILE', __DIR__ . '/webhooks.json');

// Función para conectar a la base de datos
function getDBConnection() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        return $pdo;
    } catch (PDOException $e) {
        return null;
    }
}

// Verificar autenticación y roles
function checkAuth($requiredRole = null) {
    $headers = getallheaders();
    $apiKey = isset($headers['Authorization']) ? str_replace('Bearer ', '', $headers['Authorization']) : '';

    if ($apiKey !== API_KEY) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'No autorizado']);
        exit;
    }

    // Si se requiere un rol específico, verificarlo
    if ($requiredRole) {
        $userRole = getUserRole($apiKey);
        if (!checkPermission($userRole, $requiredRole)) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Permisos insuficientes']);
            exit;
        }
    }

    return true;
}

// Obtener rol del usuario por API key
function getUserRole($apiKey) {
    // Por ahora, API_KEY principal es admin
    if ($apiKey === API_KEY) {
        return 'admin';
    }

    // Aquí puedes implementar un sistema de múltiples API keys con roles
    $pdo = getDBConnection();
    $stmt = $pdo->prepare("SELECT role FROM api_users WHERE api_key = :api_key");
    $stmt->execute(['api_key' => $apiKey]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);

    return $result ? $result['role'] : 'viewer';
}

// Verificar permisos según rol
function checkPermission($userRole, $requiredRole) {
    $roles = [
        'viewer' => 1,
        'operator' => 2,
        'admin' => 3
    ];

    return isset($roles[$userRole]) && isset($roles[$requiredRole]) &&
           $roles[$userRole] >= $roles[$requiredRole];
}

// Enviar notificación por email
function sendEmailNotification($to, $subject, $body) {
    $headers = "From: " . SMTP_FROM_NAME . " <" . SMTP_FROM . ">\r\n";
    $headers .= "Reply-To: " . SMTP_FROM . "\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";

    return mail($to, $subject, $body, $headers);
}

// Ejecutar webhooks
function triggerWebhook($event, $data) {
    if (!WEBHOOKS_ENABLED) return;

    if (!file_exists(WEBHOOKS_FILE)) return;

    $webhooks = json_decode(file_get_contents(WEBHOOKS_FILE), true);
    if (!$webhooks) return;

    foreach ($webhooks as $webhook) {
        if (in_array($event, $webhook['events'])) {
            $ch = curl_init($webhook['url']);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
                'event' => $event,
                'data' => $data,
                'timestamp' => date('c')
            ]));
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 5);
            curl_exec($ch);
            curl_close($ch);
        }
    }
}

// Función para enviar respuesta
function sendResponse($success, $message, $data = null) {
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data
    ]);
    exit;
}

// Verificar autenticación en todas las peticiones excepto login
$requestUri = $_SERVER['REQUEST_URI'];
if (strpos($requestUri, '/login') === false) {
    checkAuth();
}

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

// Router básico
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$pathParts = explode('/', trim($path, '/'));
$action = end($pathParts);

try {
    $pdo = getDBConnection();
    if (!$pdo) {
        throw new Exception('Error al conectar con la base de datos');
    }

    switch ($action) {
        case 'login':
            // Endpoint simple de login para verificar API key
            if ($method === 'POST') {
                $apiKey = $input['api_key'] ?? '';
                if ($apiKey === API_KEY) {
                    sendResponse(true, 'Login exitoso', ['token' => API_KEY]);
                } else {
                    http_response_code(401);
                    sendResponse(false, 'API key inválida');
                }
            }
            break;

        case 'users':
            if ($method === 'GET') {
                // Listar usuarios
                $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
                $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
                $search = isset($_GET['search']) ? $_GET['search'] : '';

                $sql = "SELECT u.id, u.username, r.value as password, 
                               GROUP_CONCAT(DISTINCT CONCAT(ra.attribute, '=', ra.value)) as attributes
                        FROM radcheck u
                        LEFT JOIN radcheck r ON u.username = r.username AND r.attribute = 'Cleartext-Password'
                        LEFT JOIN radreply ra ON u.username = ra.username
                        WHERE u.attribute = 'Cleartext-Password'";
                
                if ($search) {
                    $sql .= " AND u.username LIKE :search";
                }
                
                $sql .= " GROUP BY u.username ORDER BY u.id DESC LIMIT :limit OFFSET :offset";
                
                $stmt = $pdo->prepare($sql);
                if ($search) {
                    $stmt->bindValue(':search', "%$search%", PDO::PARAM_STR);
                }
                $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
                $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
                $stmt->execute();
                
                $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                // Contar total
                $countSql = "SELECT COUNT(DISTINCT username) as total FROM radcheck WHERE attribute = 'Cleartext-Password'";
                if ($search) {
                    $countSql .= " AND username LIKE :search";
                }
                $countStmt = $pdo->prepare($countSql);
                if ($search) {
                    $countStmt->bindValue(':search', "%$search%", PDO::PARAM_STR);
                }
                $countStmt->execute();
                $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
                
                sendResponse(true, 'Usuarios obtenidos', ['users' => $users, 'total' => $total]);
            } elseif ($method === 'POST') {
                // Crear usuario
                $username = $input['username'] ?? '';
                $password = $input['password'] ?? '';
                $profile = $input['profile'] ?? '';
                $bandwidth_up = $input['bandwidth_up'] ?? '10M';
                $bandwidth_down = $input['bandwidth_down'] ?? '10M';
                
                if (empty($username) || empty($password)) {
                    sendResponse(false, 'Usuario y contraseña son requeridos');
                }
                
                // Verificar si el usuario ya existe
                $stmt = $pdo->prepare("SELECT COUNT(*) FROM radcheck WHERE username = :username");
                $stmt->execute(['username' => $username]);
                if ($stmt->fetchColumn() > 0) {
                    sendResponse(false, 'El usuario ya existe');
                }
                
                $pdo->beginTransaction();
                
                // Insertar en radcheck (autenticación)
                $stmt = $pdo->prepare("INSERT INTO radcheck (username, attribute, op, value) VALUES (:username, 'Cleartext-Password', ':=', :password)");
                $stmt->execute(['username' => $username, 'password' => $password]);
                
                // Insertar en radreply (atributos de respuesta)
                // Límite de velocidad upload
                $stmt = $pdo->prepare("INSERT INTO radreply (username, attribute, op, value) VALUES (:username, 'Huawei-Input-Average-Rate', ':=', :rate)");
                $stmt->execute(['username' => $username, 'rate' => $bandwidth_up]);
                
                // Límite de velocidad download
                $stmt = $pdo->prepare("INSERT INTO radreply (username, attribute, op, value) VALUES (:username, 'Huawei-Output-Average-Rate', ':=', :rate)");
                $stmt->execute(['username' => $username, 'rate' => $bandwidth_down]);
                
                // Si se especifica un perfil, agregarlo a radusergroup
                if (!empty($profile)) {
                    $stmt = $pdo->prepare("INSERT INTO radusergroup (username, groupname, priority) VALUES (:username, :groupname, 0)");
                    $stmt->execute(['username' => $username, 'groupname' => $profile]);
                }
                
                // Insertar en userinfo (información adicional)
                $stmt = $pdo->prepare("INSERT INTO userinfo (username, creationdate, creationby) VALUES (:username, NOW(), 'API')");
                $stmt->execute(['username' => $username]);
                
                $pdo->commit();

                // Trigger webhook y notificación
                triggerWebhook('user.created', ['username' => $username]);

                sendResponse(true, 'Usuario creado exitosamente', ['username' => $username]);
            }
            break;

        case 'user':
            if ($method === 'GET') {
                // Obtener un usuario específico
                $username = $_GET['username'] ?? '';
                if (empty($username)) {
                    sendResponse(false, 'Username requerido');
                }
                
                $stmt = $pdo->prepare("SELECT * FROM radcheck WHERE username = :username");
                $stmt->execute(['username' => $username]);
                $user = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                $stmt = $pdo->prepare("SELECT * FROM radreply WHERE username = :username");
                $stmt->execute(['username' => $username]);
                $reply = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                sendResponse(true, 'Usuario obtenido', ['check' => $user, 'reply' => $reply]);
                
            } elseif ($method === 'PUT') {
                // Actualizar usuario
                $username = $input['username'] ?? '';
                $password = $input['password'] ?? '';
                $bandwidth_up = $input['bandwidth_up'] ?? null;
                $bandwidth_down = $input['bandwidth_down'] ?? null;
                
                if (empty($username)) {
                    sendResponse(false, 'Username requerido');
                }
                
                $pdo->beginTransaction();
                
                // Actualizar contraseña si se proporciona
                if (!empty($password)) {
                    $stmt = $pdo->prepare("UPDATE radcheck SET value = :password WHERE username = :username AND attribute = 'Cleartext-Password'");
                    $stmt->execute(['username' => $username, 'password' => $password]);
                }
                
                // Actualizar bandwidth upload
                if ($bandwidth_up !== null) {
                    $stmt = $pdo->prepare("UPDATE radreply SET value = :rate WHERE username = :username AND attribute = 'Huawei-Input-Average-Rate'");
                    $stmt->execute(['username' => $username, 'rate' => $bandwidth_up]);
                }
                
                // Actualizar bandwidth download
                if ($bandwidth_down !== null) {
                    $stmt = $pdo->prepare("UPDATE radreply SET value = :rate WHERE username = :username AND attribute = 'Huawei-Output-Average-Rate'");
                    $stmt->execute(['username' => $username, 'rate' => $bandwidth_down]);
                }
                
                $pdo->commit();

                // Trigger webhook
                triggerWebhook('user.updated', ['username' => $username]);

                sendResponse(true, 'Usuario actualizado exitosamente');

            } elseif ($method === 'DELETE') {
                // Eliminar usuario
                $username = $input['username'] ?? $_GET['username'] ?? '';
                if (empty($username)) {
                    sendResponse(false, 'Username requerido');
                }
                
                $pdo->beginTransaction();
                
                $stmt = $pdo->prepare("DELETE FROM radcheck WHERE username = :username");
                $stmt->execute(['username' => $username]);
                
                $stmt = $pdo->prepare("DELETE FROM radreply WHERE username = :username");
                $stmt->execute(['username' => $username]);
                
                $stmt = $pdo->prepare("DELETE FROM radusergroup WHERE username = :username");
                $stmt->execute(['username' => $username]);
                
                $stmt = $pdo->prepare("DELETE FROM userinfo WHERE username = :username");
                $stmt->execute(['username' => $username]);
                
                $pdo->commit();

                // Trigger webhook
                triggerWebhook('user.deleted', ['username' => $username]);

                sendResponse(true, 'Usuario eliminado exitosamente');
            }
            break;

        case 'export':
            // Exportar usuarios a CSV
            if ($method === 'GET') {
                $format = $_GET['format'] ?? 'csv';

                $sql = "SELECT u.username, r.value as password,
                               ra_up.value as bandwidth_up,
                               ra_down.value as bandwidth_down,
                               ug.groupname as profile,
                               ui.creationdate
                        FROM radcheck u
                        LEFT JOIN radcheck r ON u.username = r.username AND r.attribute = 'Cleartext-Password'
                        LEFT JOIN radreply ra_up ON u.username = ra_up.username AND ra_up.attribute = 'Huawei-Input-Average-Rate'
                        LEFT JOIN radreply ra_down ON u.username = ra_down.username AND ra_down.attribute = 'Huawei-Output-Average-Rate'
                        LEFT JOIN radusergroup ug ON u.username = ug.username
                        LEFT JOIN userinfo ui ON u.username = ui.username
                        WHERE u.attribute = 'Cleartext-Password'
                        ORDER BY u.id DESC";

                $stmt = $pdo->query($sql);
                $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

                if ($format === 'csv') {
                    header('Content-Type: text/csv; charset=utf-8');
                    header('Content-Disposition: attachment; filename="usuarios_radius_' . date('Y-m-d') . '.csv"');

                    $output = fopen('php://output', 'w');
                    fputcsv($output, ['Usuario', 'Contraseña', 'Upload', 'Download', 'Perfil', 'Fecha Creación']);

                    foreach ($users as $user) {
                        fputcsv($output, [
                            $user['username'],
                            $user['password'],
                            $user['bandwidth_up'] ?? 'N/A',
                            $user['bandwidth_down'] ?? 'N/A',
                            $user['profile'] ?? 'default',
                            $user['creationdate'] ?? 'N/A'
                        ]);
                    }

                    fclose($output);
                    exit;
                } else {
                    sendResponse(true, 'Datos exportados', $users);
                }
            }
            break;

        case 'history':
            // Historial de conexiones de un usuario
            if ($method === 'GET') {
                $username = $_GET['username'] ?? '';
                $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;

                if (empty($username)) {
                    sendResponse(false, 'Username requerido');
                }

                $sql = "SELECT radacctid, acctstarttime, acctstoptime, acctsessiontime,
                               acctinputoctets, acctoutputoctets, framedipaddress, nasipaddress
                        FROM radacct
                        WHERE username = :username
                        ORDER BY acctstarttime DESC
                        LIMIT :limit";

                $stmt = $pdo->prepare($sql);
                $stmt->bindValue(':username', $username, PDO::PARAM_STR);
                $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
                $stmt->execute();

                $history = $stmt->fetchAll(PDO::FETCH_ASSOC);

                sendResponse(true, 'Historial obtenido', $history);
            }
            break;

        case 'bandwidth-stats':
            // Estadísticas de uso de ancho de banda
            if ($method === 'GET') {
                $username = $_GET['username'] ?? '';
                $days = isset($_GET['days']) ? intval($_GET['days']) : 30;

                $sql = "SELECT DATE(acctstarttime) as date,
                               SUM(acctinputoctets) as input_bytes,
                               SUM(acctoutputoctets) as output_bytes,
                               SUM(acctsessiontime) as total_time
                        FROM radacct
                        WHERE acctstarttime >= DATE_SUB(NOW(), INTERVAL :days DAY)";

                if (!empty($username)) {
                    $sql .= " AND username = :username";
                }

                $sql .= " GROUP BY DATE(acctstarttime) ORDER BY date DESC";

                $stmt = $pdo->prepare($sql);
                $stmt->bindValue(':days', $days, PDO::PARAM_INT);

                if (!empty($username)) {
                    $stmt->bindValue(':username', $username, PDO::PARAM_STR);
                }

                $stmt->execute();
                $stats = $stmt->fetchAll(PDO::FETCH_ASSOC);

                sendResponse(true, 'Estadísticas de ancho de banda obtenidas', $stats);
            }
            break;

        case 'webhooks':
            // Gestión de webhooks
            if ($method === 'GET') {
                // Listar webhooks
                if (file_exists(WEBHOOKS_FILE)) {
                    $webhooks = json_decode(file_get_contents(WEBHOOKS_FILE), true);
                    sendResponse(true, 'Webhooks obtenidos', $webhooks ?? []);
                } else {
                    sendResponse(true, 'No hay webhooks configurados', []);
                }
            } elseif ($method === 'POST') {
                // Crear webhook
                $url = $input['url'] ?? '';
                $events = $input['events'] ?? [];

                if (empty($url) || empty($events)) {
                    sendResponse(false, 'URL y eventos son requeridos');
                }

                $webhooks = [];
                if (file_exists(WEBHOOKS_FILE)) {
                    $webhooks = json_decode(file_get_contents(WEBHOOKS_FILE), true) ?? [];
                }

                $webhooks[] = [
                    'id' => uniqid(),
                    'url' => $url,
                    'events' => $events,
                    'created_at' => date('c')
                ];

                file_put_contents(WEBHOOKS_FILE, json_encode($webhooks, JSON_PRETTY_PRINT));

                sendResponse(true, 'Webhook creado exitosamente', $webhooks[count($webhooks) - 1]);
            } elseif ($method === 'DELETE') {
                // Eliminar webhook
                $id = $input['id'] ?? $_GET['id'] ?? '';

                if (empty($id)) {
                    sendResponse(false, 'ID requerido');
                }

                if (file_exists(WEBHOOKS_FILE)) {
                    $webhooks = json_decode(file_get_contents(WEBHOOKS_FILE), true) ?? [];
                    $webhooks = array_filter($webhooks, function($w) use ($id) {
                        return $w['id'] !== $id;
                    });

                    file_put_contents(WEBHOOKS_FILE, json_encode(array_values($webhooks), JSON_PRETTY_PRINT));

                    sendResponse(true, 'Webhook eliminado exitosamente');
                } else {
                    sendResponse(false, 'No hay webhooks configurados');
                }
            }
            break;

        case 'stats':
            // Estadísticas generales
            if ($method === 'GET') {
                $stmt = $pdo->query("SELECT COUNT(DISTINCT username) as total_users FROM radcheck WHERE attribute = 'Cleartext-Password'");
                $totalUsers = $stmt->fetch(PDO::FETCH_ASSOC)['total_users'];
                
                $stmt = $pdo->query("SELECT COUNT(*) as active_sessions FROM radacct WHERE acctstoptime IS NULL");
                $activeSessions = $stmt->fetch(PDO::FETCH_ASSOC)['active_sessions'];
                
                sendResponse(true, 'Estadísticas obtenidas', [
                    'total_users' => $totalUsers,
                    'active_sessions' => $activeSessions
                ]);
            }
            break;

        default:
            sendResponse(false, 'Endpoint no encontrado');
    }
    
} catch (Exception $e) {
    http_response_code(500);
    sendResponse(false, 'Error: ' . $e->getMessage());
}
