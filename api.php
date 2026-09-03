<?php
// ================================================================
// SMART ZERO WASTE CITY - API Endpoint
// ================================================================

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// ==================== DATABASE CONFIGURATION ====================
// ✅ FILLED WITH YOUR VALUES

$DB_HOST = 'sql311.infinityfree.com';
$DB_NAME = 'if0_42329659_db_SZWC';
$DB_USER = 'if0_42329659';
$DB_PASS = 'joshvaadmin123';

// ==================== CONNECT TO DATABASE ====================
try {
    $pdo = new PDO("mysql:host=$DB_HOST;dbname=$DB_NAME;charset=utf8mb4", $DB_USER, $DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit;
}

// ==================== GET ACTION ====================
$action = isset($_GET['action']) ? $_GET['action'] : (isset($_POST['action']) ? $_POST['action'] : '');

// ==================== 1. REGISTER (SIGNUP) ====================
if ($action === 'register') {
    $username = isset($_POST['username']) ? trim($_POST['username']) : '';
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    $email = isset($_POST['email']) ? trim($_POST['email']) : '';
    $name = isset($_POST['name']) ? trim($_POST['name']) : '';
    $phone = isset($_POST['phone']) ? trim($_POST['phone']) : '';
    
    if (empty($username) || empty($password) || empty($email)) {
        echo json_encode(['success' => false, 'message' => 'Username, password and email required']);
        exit;
    }
    
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    if ($stmt->fetch()) {
        echo json_encode(['success' => false, 'message' => 'Username already taken']);
        exit;
    }
    
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        echo json_encode(['success' => false, 'message' => 'Email already registered']);
        exit;
    }
    
    $stmt = $pdo->prepare("INSERT INTO users (username, password, email, name, phone, role, created_at) 
                           VALUES (?, MD5(?), ?, ?, ?, 'citizen', NOW())");
    $stmt->execute([$username, $password, $email, $name, $phone]);
    
    echo json_encode(['success' => true, 'message' => 'Registration successful! Please login.']);
    exit;
}

// ==================== 2. LOGIN ====================
if ($action === 'login') {
    $username = isset($_POST['username']) ? $_POST['username'] : '';
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    
    if (empty($username) || empty($password)) {
        echo json_encode(['success' => false, 'message' => 'Username and password required']);
        exit;
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND password = MD5(?) AND is_active = 1");
    $stmt->execute([$username, $password]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo json_encode([
            'success' => true,
            'username' => $user['username'],
            'role' => $user['role'],
            'name' => $user['name'],
            'email' => $user['email'],
            'user_id' => $user['id']
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid username or password']);
    }
    exit;
}

// ==================== 3. BIN UPDATE (From IoT Bin) ====================
if ($action === 'bin_update') {
    $bin_id = isset($_POST['bin_id']) ? $_POST['bin_id'] : '';
    $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : 0;
    $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : 0;
    $fill_level = isset($_POST['fill_level']) ? floatval($_POST['fill_level']) : 0;
    $api_key = isset($_POST['api_key']) ? $_POST['api_key'] : '';
    
    $stmt = $pdo->prepare("SELECT id FROM esp_devices WHERE api_key = ? AND status = 'ONLINE'");
    $stmt->execute([$api_key]);
    if (!$stmt->fetch()) {
        echo json_encode(['success' => false, 'message' => 'Invalid API key']);
        exit;
    }
    
    $stmt = $pdo->prepare("INSERT INTO bins (bin_id, latitude, longitude, fill_level, last_updated, status) 
                           VALUES (?, ?, ?, ?, NOW(), 'ACTIVE') 
                           ON DUPLICATE KEY UPDATE 
                           latitude = VALUES(latitude), 
                           longitude = VALUES(longitude), 
                           fill_level = VALUES(fill_level), 
                           last_updated = NOW()");
    $stmt->execute([$bin_id, $latitude, $longitude, $fill_level]);
    
    echo json_encode(['success' => true, 'message' => 'Bin updated successfully']);
    exit;
}

// ==================== 4. GET BINS ====================
if ($action === 'get_bins') {
    $stmt = $pdo->query("SELECT * FROM bins WHERE status != 'INACTIVE' ORDER BY fill_level DESC");
    $bins = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'bins' => $bins]);
    exit;
}

// ==================== 5. REQUEST COLLECTION ====================
if ($action === 'request_collection') {
    $citizen_id = isset($_POST['citizen_id']) ? $_POST['citizen_id'] : '';
    $bin_id = isset($_POST['bin_id']) ? $_POST['bin_id'] : '';
    $latitude = isset($_POST['latitude']) ? floatval($_POST['latitude']) : 0;
    $longitude = isset($_POST['longitude']) ? floatval($_POST['longitude']) : 0;
    $address = isset($_POST['address']) ? $_POST['address'] : '';
    $waste_type = isset($_POST['waste_type']) ? $_POST['waste_type'] : 'Mixed';
    $notes = isset($_POST['notes']) ? $_POST['notes'] : '';
    
    $stmt = $pdo->prepare("SELECT robot_id FROM robots WHERE status = 'IDLE' ORDER BY battery_level DESC LIMIT 1");
    $stmt->execute();
    $robot = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$robot) {
        echo json_encode(['success' => false, 'message' => 'No robots available']);
        exit;
    }
    
    $robot_id = $robot['robot_id'];
    
    $stmt = $pdo->prepare("INSERT INTO collection_requests 
                           (citizen_id, bin_id, robot_id, latitude, longitude, address, waste_type, notes, status, request_time) 
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', NOW())");
    $stmt->execute([$citizen_id, $bin_id, $robot_id, $latitude, $longitude, $address, $waste_type, $notes]);
    
    $request_id = $pdo->lastInsertId();
    
    echo json_encode([
        'success' => true, 
        'message' => 'Collection requested', 
        'request_id' => $request_id,
        'robot_id' => $robot_id
    ]);
    exit;
}

// ==================== 6. REGISTER ESP32 DEVICE ====================
if ($action === 'register_device') {
    $device_id = isset($_POST['device_id']) ? $_POST['device_id'] : '';
    $api_key = isset($_POST['api_key']) ? $_POST['api_key'] : '';
    $name = isset($_POST['name']) ? $_POST['name'] : '';
    $robot_id = isset($_POST['robot_id']) ? $_POST['robot_id'] : '';
    
    $stmt = $pdo->prepare("INSERT INTO esp_devices (device_id, api_key, name, robot_id, status, connected_at) 
                           VALUES (?, ?, ?, ?, 'ONLINE', NOW()) 
                           ON DUPLICATE KEY UPDATE 
                           status = 'ONLINE', 
                           connected_at = NOW()");
    $stmt->execute([$device_id, $api_key, $name, $robot_id]);
    
    echo json_encode(['success' => true, 'message' => 'Device registered']);
    exit;
}

// ==================== 7. GET ROBOTS ====================
if ($action === 'get_robots') {
    $stmt = $pdo->query("SELECT * FROM robots ORDER BY status");
    $robots = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'robots' => $robots]);
    exit;
}

// ==================== 8. GET HISTORY ====================
if ($action === 'get_history') {
    $citizen_id = isset($_GET['citizen_id']) ? $_GET['citizen_id'] : '';
    
    if ($citizen_id) {
        $stmt = $pdo->prepare("SELECT * FROM collection_history WHERE citizen_id = ? ORDER BY collection_time DESC LIMIT 50");
        $stmt->execute([$citizen_id]);
    } else {
        $stmt = $pdo->query("SELECT * FROM collection_history ORDER BY collection_time DESC LIMIT 50");
    }
    $history = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'history' => $history]);
    exit;
}

// ==================== 9. GET SYSTEM SETTINGS ====================
if ($action === 'get_settings') {
    $stmt = $pdo->query("SELECT * FROM system_settings");
    $settings = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $settings[$row['setting_key']] = $row['setting_value'];
    }
    echo json_encode(['success' => true, 'settings' => $settings]);
    exit;
}

// ==================== 10. UPDATE SYSTEM SETTINGS ====================
if ($action === 'update_settings') {
    $key = isset($_POST['key']) ? $_POST['key'] : '';
    $value = isset($_POST['value']) ? $_POST['value'] : '';
    
    if (empty($key)) {
        echo json_encode(['success' => false, 'message' => 'Setting key required']);
        exit;
    }
    
    $stmt = $pdo->prepare("UPDATE system_settings SET setting_value = ? WHERE setting_key = ?");
    $stmt->execute([$value, $key]);
    
    echo json_encode(['success' => true, 'message' => 'Setting updated']);
    exit;
}

// ==================== DEFAULT RESPONSE ====================
echo json_encode(['success' => false, 'message' => 'Invalid action']);
?>