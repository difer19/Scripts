#!/bin/bash

# Script completo para montar API + nginx HTTPS desde cero
# No depende de configuraciones previas

set -e

echo "=========================================="
echo "🚀 Instalación completa: nginx HTTPS + API"
echo "=========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Variables
SERVER_IP=$(hostname -I | awk '{print $1}')
API_DIR="/opt/test-api"
API_PORT="3000"
API_USER="apiuser"
CERT_DIR="/etc/nginx/ssl"

print_status "Configuración detectada:"
echo "  - IP del servidor: $SERVER_IP"
echo "  - Directorio API: $API_DIR"
echo "  - Puerto API: $API_PORT"
echo ""

# 1. Actualizar sistema e instalar dependencias
print_status "Actualizando sistema e instalando dependencias..."
apt update
apt install -y nginx openssl curl

# 2. Instalar Node.js
print_status "Instalando Node.js..."
if ! command -v node > /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

node_version=$(node --version)
print_success "Node.js $node_version instalado"

# 3. Crear usuario para API
if ! id "$API_USER" &>/dev/null; then
    print_status "Creando usuario para el API..."
    useradd -r -s /bin/bash -m -d "$API_DIR" "$API_USER"
fi

# 4. Crear certificados SSL con mkcert
print_status "Creando certificados SSL válidos con mkcert..."

apt install -y libnss3-tools # necesario para Firefox/Chrome confiar en CA
if ! command -v mkcert > /dev/null; then
    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    chmod +x mkcert-v*-linux-amd64
    mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
    mkcert -install
fi

mkdir -p $CERT_DIR

# dominio local
DOMAIN="miapi.local"

mkcert -cert-file $CERT_DIR/nginx-cert.pem -key-file $CERT_DIR/nginx-key.pem $DOMAIN

# ajustar permisos
chmod 600 $CERT_DIR/nginx-key.pem
chmod 644 $CERT_DIR/nginx-cert.pem

# 5. Crear snippets SSL
print_status "Configurando SSL snippets..."
mkdir -p /etc/nginx/snippets

cat > /etc/nginx/snippets/self-signed.conf << EOF
ssl_certificate $CERT_DIR/nginx-selfsigned.crt;
ssl_certificate_key $CERT_DIR/nginx-selfsigned.key;
EOF

cat > /etc/nginx/snippets/ssl-params.conf << EOF
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam $CERT_DIR/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF

# 6. Crear proyecto API
print_status "Creando proyecto API..."
mkdir -p "$API_DIR"
cd "$API_DIR"

cat > package.json << 'EOF'
{
  "name": "test-api",
  "version": "1.0.0",
  "description": "API de prueba para servidor nginx HTTPS",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0"
  }
}
EOF

print_status "Instalando dependencias del API..."
npm install

# 7. Crear servidor API
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuración CORS para acceso externo
const corsOptions = {
    origin: true, // Permite todos los orígenes
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization']
};

app.use(helmet({ crossOriginEmbedderPolicy: false }));
app.use(cors(corsOptions));
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Base de datos en memoria
let users = [
    { id: 1, name: 'Juan Pérez', email: 'juan@ejemplo.com', city: 'Pasto' },
    { id: 2, name: 'María González', email: 'maria@ejemplo.com', city: 'Bogotá' },
    { id: 3, name: 'Carlos Rodríguez', email: 'carlos@ejemplo.com', city: 'Medellín' }
];

let products = [
    { id: 1, name: 'Laptop HP', price: 2500000, category: 'Electrónicos', stock: 10 },
    { id: 2, name: 'Mouse Logitech', price: 85000, category: 'Accesorios', stock: 25 },
    { id: 3, name: 'Teclado Mecánico', price: 250000, category: 'Accesorios', stock: 15 }
];

// Endpoints
app.get('/', (req, res) => {
    res.json({
        message: '¡API funcionando!',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        endpoints: ['/api/users', '/api/products', '/api/health']
    });
});

app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        server: 'nginx + Node.js'
    });
});

app.get('/api/users', (req, res) => {
    res.json({ success: true, data: users });
});

app.get('/api/users/:id', (req, res) => {
    const user = users.find(u => u.id === parseInt(req.params.id));
    if (!user) return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    res.json({ success: true, data: user });
});

app.post('/api/users', (req, res) => {
    const { name, email, city } = req.body;
    if (!name || !email) {
        return res.status(400).json({ success: false, message: 'Nombre y email requeridos' });
    }
    const newUser = {
        id: Math.max(...users.map(u => u.id)) + 1,
        name, email, city: city || 'No especificada'
    };
    users.push(newUser);
    res.status(201).json({ success: true, data: newUser });
});

app.get('/api/products', (req, res) => {
    res.json({ success: true, data: products });
});

app.use('*', (req, res) => {
    res.status(404).json({ success: false, message: 'Ruta no encontrada' });
});

app.listen(PORT, '127.0.0.1', () => {
    console.log(`🚀 API corriendo en http://127.0.0.1:${PORT}`);
});
EOF

# 8. Crear servicio systemd
print_status "Creando servicio systemd..."
cat > /etc/systemd/system/test-api.service << EOF
[Unit]
Description=Test API Server
After=network.target

[Service]
Type=simple
User=$API_USER
ExecStart=/usr/bin/node $API_DIR/server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 9. Configurar nginx
print_status "Configurando nginx..."
cat > /etc/nginx/sites-available/complete-api << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    root /var/www/html;
    index index.html;

    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # CORS headers
    add_header Access-Control-Allow-Origin \$http_origin always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
    add_header Access-Control-Allow-Credentials true always;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin \$http_origin;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization";
            add_header Access-Control-Allow-Credentials true;
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }

        proxy_pass http://127.0.0.1:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 10. Crear página web
print_status "Creando página web..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API + nginx HTTPS</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin: 0;
            padding: 2rem;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            background: rgba(255,255,255,0.1);
            padding: 2rem;
            border-radius: 15px;
            margin-bottom: 2rem;
        }
        .info {
            background: rgba(255,255,255,0.1);
            padding: 2rem;
            border-radius: 15px;
            margin-bottom: 2rem;
        }
        .test-buttons {
            text-align: center;
            margin: 2rem 0;
        }
        button {
            background: #4ade80;
            color: black;
            border: none;
            padding: 1rem 2rem;
            margin: 0.5rem;
            border-radius: 25px;
            cursor: pointer;
            font-weight: bold;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .response {
            background: rgba(0,0,0,0.3);
            padding: 1rem;
            border-radius: 10px;
            max-height: 300px;
            overflow-y: auto;
            margin-top: 1rem;
        }
        pre {
            white-space: pre-wrap;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 API + nginx HTTPS</h1>
            <p>Servidor funcionando correctamente</p>
        </div>

        <div class="info">
            <h2>📡 Información del servidor</h2>
            <p><strong>IP:</strong> $SERVER_IP</p>
            <p><strong>URL externa:</strong> https://$SERVER_IP/</p>
            <p><strong>API externa:</strong> https://$SERVER_IP/api/</p>
        </div>

        <div class="test-buttons">
            <h2>🧪 Pruebas</h2>
            <button onclick="testAPI('/api/health')">Health Check</button>
            <button onclick="testAPI('/api/users')">Ver Usuarios</button>
            <button onclick="testAPI('/api/products')">Ver Productos</button>
        </div>

        <div class="response" id="response" style="display:none;">
            <h3>Respuesta:</h3>
            <pre id="responseContent"></pre>
        </div>
    </div>

    <script>
        async function testAPI(endpoint) {
            const responseDiv = document.getElementById('response');
            const responseContent = document.getElementById('responseContent');
            
            try {
                responseDiv.style.display = 'block';
                responseContent.textContent = 'Cargando...';
                
                const response = await fetch(endpoint);
                const data = await response.json();
                
                responseContent.textContent = JSON.stringify(data, null, 2);
            } catch (error) {
                responseContent.textContent = 'Error: ' + error.message;
            }
        }
    </script>
</body>
</html>
EOF

# 11. Configurar permisos
chown -R $API_USER:$API_USER $API_DIR

# 12. Habilitar configuración
rm -f /etc/nginx/sites-enabled/*
ln -sf /etc/nginx/sites-available/complete-api /etc/nginx/sites-enabled/

# 13. Verificar configuración nginx
print_status "Verificando configuración nginx..."
if nginx -t; then
    print_success "Configuración nginx válida"
else
    print_error "Error en configuración nginx"
    exit 1
fi

# 14. Configurar firewall
if command -v ufw > /dev/null; then
    print_status "Configurando firewall..."
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

# 15. Iniciar servicios
print_status "Iniciando servicios..."
systemctl daemon-reload
systemctl enable nginx test-api
systemctl start test-api
systemctl reload nginx

# 16. Verificar servicios
sleep 3
if systemctl is-active --quiet nginx && systemctl is-active --quiet test-api; then
    print_success "Todos los servicios funcionando"
else
    print_error "Algunos servicios fallaron"
    systemctl status nginx
    systemctl status test-api
    exit 1
fi

# 17. Resultado final
echo ""
echo "=========================================="
print_success "¡Instalación completada exitosamente!"
echo "=========================================="
echo ""
echo "🌐 URLs disponibles:"
echo "  - Web: https://$SERVER_IP/"
echo "  - API Health: https://$SERVER_IP/api/health"
echo "  - API Users: https://$SERVER_IP/api/users"
echo ""
echo "🧪 Prueba desde terminal:"
echo "  curl -k https://$SERVER_IP/api/health"
echo "  curl -k https://localhost/api/users"
echo ""
echo "📋 Comandos útiles:"
echo "  - Estado API: systemctl status test-api"
echo "  - Estado nginx: systemctl status nginx"
echo "  - Logs API: journalctl -u test-api -f"
echo "  - Logs nginx: tail -f /var/log/nginx/api_access.log"
echo ""
print_warning "Certificado autofirmado - acepta advertencia del navegador"
print_success "¡Listo para usar desde cualquier dispositivo en la red!"
