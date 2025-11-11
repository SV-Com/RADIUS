// Configuración - CAMBIAR ESTA URL POR LA DE TU SERVIDOR
const API_URL = 'http://TU_SERVIDOR/radius-api.php';
let apiToken = localStorage.getItem('radiusApiToken');
let currentUser = null;

// ==================== AUTENTICACIÓN ====================

// Login
document.getElementById('loginForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const apiKey = document.getElementById('apiKeyInput').value;

    try {
        const response = await fetch(`${API_URL}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ api_key: apiKey })
        });

        const data = await response.json();

        if (data.success) {
            apiToken = data.data.token;
            localStorage.setItem('radiusApiToken', apiToken);
            document.getElementById('loginScreen').style.display = 'none';
            document.getElementById('mainApp').style.display = 'block';
            loadUsers();
            loadStats();
        } else {
            showLoginAlert('API Key incorrecta', 'error');
        }
    } catch (error) {
        showLoginAlert('Error al conectar con el servidor', 'error');
    }
});

// Logout
function logout() {
    localStorage.removeItem('radiusApiToken');
    apiToken = null;
    document.getElementById('loginScreen').style.display = 'block';
    document.getElementById('mainApp').style.display = 'none';
}

// Verificar si ya está logueado
if (apiToken) {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('mainApp').style.display = 'block';
    loadUsers();
    loadStats();
}

// ==================== ALERTAS ====================

function showLoginAlert(message, type) {
    const alertDiv = document.getElementById('loginAlert');
    alertDiv.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
    setTimeout(() => alertDiv.innerHTML = '', 5000);
}

function showAlert(message, type) {
    const alertDiv = document.getElementById('alertContainer');
    alertDiv.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
    setTimeout(() => alertDiv.innerHTML = '', 5000);
}

// ==================== ESTADÍSTICAS ====================

async function loadStats() {
    try {
        const response = await fetch(`${API_URL}/stats`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });
        const data = await response.json();

        if (data.success) {
            document.getElementById('totalUsers').textContent = data.data.total_users;
            document.getElementById('activeSessions').textContent = data.data.active_sessions;
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// ==================== USUARIOS ====================

async function loadUsers(search = '') {
    try {
        const url = new URL(`${API_URL}/users`);
        if (search) url.searchParams.append('search', search);

        const response = await fetch(url, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });
        const data = await response.json();

        if (data.success) {
            displayUsers(data.data.users);
        }
    } catch (error) {
        console.error('Error loading users:', error);
        document.getElementById('usersTableBody').innerHTML = `
            <tr><td colspan="5" style="text-align: center; color: #e74c3c;">
                Error al cargar usuarios. Verifica la conexión con el servidor.
            </td></tr>
        `;
    }
}

function displayUsers(users) {
    const tbody = document.getElementById('usersTableBody');

    if (users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align: center;">No hay usuarios</td></tr>';
        return;
    }

    tbody.innerHTML = users.map(user => `
        <tr>
            <td><strong>${user.username}</strong></td>
            <td>••••••••</td>
            <td><small>${user.attributes || 'Sin atributos'}</small></td>
            <td>
                <button class="btn btn-sm btn-success" onclick="viewHistory('${user.username}')" title="Ver historial">
                    📊
                </button>
            </td>
            <td>
                <div class="action-buttons">
                    <button class="btn btn-primary btn-sm" onclick="editUser('${user.username}')">
                        ✏️ Editar
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="deleteUser('${user.username}')">
                        🗑️ Eliminar
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
}

// Search functionality
let searchTimeout;
document.getElementById('searchInput')?.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        loadUsers(e.target.value);
    }, 500);
});

// ==================== MODAL USUARIO ====================

function openCreateUserModal() {
    document.getElementById('modalTitle').textContent = 'Crear Usuario';
    document.getElementById('userForm').reset();
    document.getElementById('username').disabled = false;
    document.getElementById('userModal').classList.add('active');
    currentUser = null;
}

function closeModal() {
    document.getElementById('userModal').classList.remove('active');
    document.getElementById('historyModal')?.classList.remove('active');
    document.getElementById('webhookModal')?.classList.remove('active');
}

// Crear/Editar usuario
document.getElementById('userForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();

    const userData = {
        username: document.getElementById('username').value,
        password: document.getElementById('password').value,
        bandwidth_up: document.getElementById('bandwidthUp').value,
        bandwidth_down: document.getElementById('bandwidthDown').value,
        profile: document.getElementById('profile').value
    };

    try {
        const method = currentUser ? 'PUT' : 'POST';
        const endpoint = currentUser ? `${API_URL}/user` : `${API_URL}/users`;

        const response = await fetch(endpoint, {
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiToken}`
            },
            body: JSON.stringify(userData)
        });

        const data = await response.json();

        if (data.success) {
            showAlert(currentUser ? 'Usuario actualizado exitosamente' : 'Usuario creado exitosamente', 'success');
            closeModal();
            loadUsers();
            loadStats();
        } else {
            showAlert(data.message, 'error');
        }
    } catch (error) {
        showAlert('Error al procesar usuario', 'error');
    }
});

// Editar usuario
async function editUser(username) {
    try {
        const response = await fetch(`${API_URL}/user?username=${username}`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success) {
            currentUser = username;
            document.getElementById('modalTitle').textContent = 'Editar Usuario';
            document.getElementById('username').value = username;
            document.getElementById('username').disabled = true;

            // Buscar valores de bandwidth
            const bandwidthUp = data.data.reply.find(r => r.attribute === 'Huawei-Input-Average-Rate');
            const bandwidthDown = data.data.reply.find(r => r.attribute === 'Huawei-Output-Average-Rate');

            if (bandwidthUp) document.getElementById('bandwidthUp').value = bandwidthUp.value;
            if (bandwidthDown) document.getElementById('bandwidthDown').value = bandwidthDown.value;

            document.getElementById('userModal').classList.add('active');
        }
    } catch (error) {
        showAlert('Error al cargar usuario', 'error');
    }
}

// Eliminar usuario
async function deleteUser(username) {
    if (!confirm(`¿Estás seguro de eliminar el usuario ${username}?`)) return;

    try {
        const response = await fetch(`${API_URL}/user?username=${username}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success) {
            showAlert('Usuario eliminado exitosamente', 'success');
            loadUsers();
            loadStats();
        } else {
            showAlert(data.message, 'error');
        }
    } catch (error) {
        showAlert('Error al eliminar usuario', 'error');
    }
}

// ==================== EXPORTAR ====================

async function exportUsers(format = 'csv') {
    try {
        const response = await fetch(`${API_URL}/export?format=${format}`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        if (format === 'csv') {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `usuarios_radius_${new Date().toISOString().split('T')[0]}.csv`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
            showAlert('Usuarios exportados exitosamente', 'success');
        } else {
            const data = await response.json();
            if (data.success) {
                console.log('Datos exportados:', data.data);
            }
        }
    } catch (error) {
        showAlert('Error al exportar usuarios', 'error');
    }
}

// ==================== HISTORIAL ====================

async function viewHistory(username) {
    try {
        const response = await fetch(`${API_URL}/history?username=${username}&limit=100`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success) {
            showHistoryModal(username, data.data);
        }
    } catch (error) {
        showAlert('Error al cargar historial', 'error');
    }
}

function showHistoryModal(username, history) {
    const modal = document.getElementById('historyModal');
    const tbody = document.getElementById('historyTableBody');

    document.getElementById('historyUsername').textContent = username;

    if (history.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No hay historial de conexiones</td></tr>';
    } else {
        tbody.innerHTML = history.map(h => {
            const start = new Date(h.acctstarttime).toLocaleString();
            const stop = h.acctstoptime ? new Date(h.acctstoptime).toLocaleString() : 'Activa';
            const duration = formatDuration(h.acctsessiontime);
            const upload = formatBytes(h.acctinputoctets);
            const download = formatBytes(h.acctoutputoctets);

            return `
                <tr>
                    <td>${start}</td>
                    <td>${stop}</td>
                    <td>${duration}</td>
                    <td>${upload}</td>
                    <td>${download}</td>
                    <td>${h.framedipaddress || 'N/A'}</td>
                </tr>
            `;
        }).join('');
    }

    modal.classList.add('active');
    loadBandwidthChart(username);
}

// ==================== GRÁFICOS ====================

async function loadBandwidthChart(username) {
    try {
        const response = await fetch(`${API_URL}/bandwidth-stats?username=${username}&days=30`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success && data.data.length > 0) {
            renderBandwidthChart(data.data);
        }
    } catch (error) {
        console.error('Error loading bandwidth stats:', error);
    }
}

function renderBandwidthChart(stats) {
    const canvas = document.getElementById('bandwidthChart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;

    // Limpiar canvas
    ctx.clearRect(0, 0, width, height);

    if (stats.length === 0) {
        ctx.fillStyle = '#666';
        ctx.font = '14px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('No hay datos disponibles', width / 2, height / 2);
        return;
    }

    // Preparar datos
    const maxInput = Math.max(...stats.map(s => parseInt(s.input_bytes)));
    const maxOutput = Math.max(...stats.map(s => parseInt(s.output_bytes)));
    const maxValue = Math.max(maxInput, maxOutput);

    const padding = 40;
    const chartWidth = width - 2 * padding;
    const chartHeight = height - 2 * padding;
    const barWidth = chartWidth / stats.length / 2 - 2;

    // Dibujar ejes
    ctx.strokeStyle = '#ccc';
    ctx.beginPath();
    ctx.moveTo(padding, padding);
    ctx.lineTo(padding, height - padding);
    ctx.lineTo(width - padding, height - padding);
    ctx.stroke();

    // Dibujar barras
    stats.reverse().forEach((stat, index) => {
        const x = padding + (index * chartWidth / stats.length);
        const inputHeight = (parseInt(stat.input_bytes) / maxValue) * chartHeight;
        const outputHeight = (parseInt(stat.output_bytes) / maxValue) * chartHeight;

        // Upload (azul)
        ctx.fillStyle = '#667eea';
        ctx.fillRect(x, height - padding - inputHeight, barWidth, inputHeight);

        // Download (verde)
        ctx.fillStyle = '#27ae60';
        ctx.fillRect(x + barWidth + 2, height - padding - outputHeight, barWidth, outputHeight);
    });

    // Leyenda
    ctx.fillStyle = '#667eea';
    ctx.fillRect(padding, 10, 20, 10);
    ctx.fillStyle = '#333';
    ctx.font = '12px Arial';
    ctx.textAlign = 'left';
    ctx.fillText('Upload', padding + 25, 18);

    ctx.fillStyle = '#27ae60';
    ctx.fillRect(padding + 100, 10, 20, 10);
    ctx.fillStyle = '#333';
    ctx.fillText('Download', padding + 125, 18);
}

// ==================== WEBHOOKS ====================

async function loadWebhooks() {
    try {
        const response = await fetch(`${API_URL}/webhooks`, {
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success) {
            displayWebhooks(data.data);
        }
    } catch (error) {
        console.error('Error loading webhooks:', error);
    }
}

function displayWebhooks(webhooks) {
    const tbody = document.getElementById('webhooksTableBody');

    if (!tbody) return;

    if (webhooks.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align: center;">No hay webhooks configurados</td></tr>';
        return;
    }

    tbody.innerHTML = webhooks.map(w => `
        <tr>
            <td>${w.url}</td>
            <td>${w.events.join(', ')}</td>
            <td>${new Date(w.created_at).toLocaleString()}</td>
            <td>
                <button class="btn btn-danger btn-sm" onclick="deleteWebhook('${w.id}')">
                    🗑️ Eliminar
                </button>
            </td>
        </tr>
    `).join('');
}

async function deleteWebhook(id) {
    if (!confirm('¿Estás seguro de eliminar este webhook?')) return;

    try {
        const response = await fetch(`${API_URL}/webhooks?id=${id}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${apiToken}` }
        });

        const data = await response.json();

        if (data.success) {
            showAlert('Webhook eliminado exitosamente', 'success');
            loadWebhooks();
        }
    } catch (error) {
        showAlert('Error al eliminar webhook', 'error');
    }
}

// ==================== UTILIDADES ====================

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

function formatDuration(seconds) {
    if (!seconds) return '0s';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours}h ${minutes}m ${secs}s`;
}
