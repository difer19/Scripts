#!/bin/bash

# Script para montar API de prueba con nginx como proxy reverso
# Autor: Script automatizado
# Fecha: $(date)

set -e  # Salir si hay algún error

echo "=========================================="
echo "Configurando API de prueba con nginx"
echo "=========================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
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

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Variables configurables
API_DIR="/opt/test-api"
API_PORT="3000"
API_USER="apiuser"
DOMAIN="localhost"
CERT_DIR="/etc/nginx/ssl"

# Crear usuario para el API si no existe
if ! id "$API_USER" &>/dev/null; then
    print_status "Creando usuario para el API..."
    useradd -r -s /bin/bash -m -d "$API_DIR" "$API_USER"
fi

# Instalar Node.js y npm
print_status "Instalando Node.js y npm..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Verificar instalación de Node.js
node_version=$(node --version)
npm_version=$(npm --version)
print_success "Node.js $node_version y npm $npm_version instalados"

# Crear directorio para el API
print_status "Creando estructura del proyecto API..."
mkdir -p "$API_DIR"
cd "$API_DIR"

# Crear package.json
print_status "Creando configuración del proyecto..."
cat > package.json << 'EOF'
{
  "name": "test-api",
  "version": "1.0.0",
  "description": "API de prueba para servidor nginx HTTPS",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0"
  },
  "keywords": ["api", "test", "nginx", "https"],
  "author": "Test API",
  "license": "MIT"
}
EOF

# Instalar dependencias
print_status "Instalando dependencias de Node.js..."
npm install

# Crear el servidor API
print_status "Creando servidor API..."
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de seguridad
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Base de datos simulada en memoria
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

// Rutas de información del API
app.get('/', (req, res) => {
    res.json({
        message: '¡API de prueba funcionando!',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        endpoints: {
            users: '/api/users',
            products: '/api/products',
            health: '/api/health',
            info: '/api/info'
        }
    });
});

app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        memory: process.memoryUsage(),
        server: 'nginx + Node.js API'
    });
});

app.get('/api/info', (req, res) => {
    res.json({
        api_name: 'Test API',
        version: '1.0.0',
        node_version: process.version,
        environment: process.env.NODE_ENV || 'development',
        port: PORT,
        timestamp: new Date().toISOString()
    });
});

// CRUD para usuarios
app.get('/api/users', (req, res) => {
    res.json({
        success: true,
        data: users,
        total: users.length
    });
});

app.get('/api/users/:id', (req, res) => {
    const user = users.find(u => u.id === parseInt(req.params.id));
    if (!user) {
        return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    res.json({ success: true, data: user });
});

app.post('/api/users', (req, res) => {
    const { name, email, city } = req.body;
    if (!name || !email) {
        return res.status(400).json({ success: false, message: 'Nombre y email requeridos' });
    }
    
    const newUser = {
        id: Math.max(...users.map(u => u.id)) + 1,
        name,
        email,
        city: city || 'No especificada'
    };
    
    users.push(newUser);
    res.status(201).json({ success: true, data: newUser });
});

app.put('/api/users/:id', (req, res) => {
    const userId = parseInt(req.params.id);
    const userIndex = users.findIndex(u => u.id === userId);
    
    if (userIndex === -1) {
        return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    
    users[userIndex] = { ...users[userIndex], ...req.body, id: userId };
    res.json({ success: true, data: users[userIndex] });
});

app.delete('/api/users/:id', (req, res) => {
    const userId = parseInt(req.params.id);
    const userIndex = users.findIndex(u => u.id === userId);
    
    if (userIndex === -1) {
        return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    
    const deletedUser = users.splice(userIndex, 1)[0];
    res.json({ success: true, message: 'Usuario eliminado', data: deletedUser });
});

// CRUD para productos
app.get('/api/products', (req, res) => {
    const { category, minPrice, maxPrice } = req.query;
    let filteredProducts = [...products];
    
    if (category) {
        filteredProducts = filteredProducts.filter(p => 
            p.category.toLowerCase().includes(category.toLowerCase())
        );
    }
    
    if (minPrice) {
        filteredProducts = filteredProducts.filter(p => p.price >= parseInt(minPrice));
    }
    
    if (maxPrice) {
        filteredProducts = filteredProducts.filter(p => p.price <= parseInt(maxPrice));
    }
    
    res.json({
        success: true,
        data: filteredProducts,
        total: filteredProducts.length,
        filters: { category, minPrice, maxPrice }
    });
});

app.get('/api/products/:id', (req, res) => {
    const product = products.find(p => p.id === parseInt(req.params.id));
    if (!product) {
        return res.status(404).json({ success: false, message: 'Producto no encontrado' });
    }
    res.json({ success: true, data: product });
});

app.post('/api/products', (req, res) => {
    const { name, price, category, stock } = req.body;
    if (!name || !price || !category) {
        return res.status(400).json({ 
            success: false, 
            message: 'Nombre, precio y categoría requeridos' 
        });
    }
    
    const newProduct = {
        id: Math.max(...products.map(p => p.id)) + 1,
        name,
        price: parseFloat(price),
        category,
        stock: parseInt(stock) || 0
    };
    
    products.push(newProduct);
    res.status(201).json({ success: true, data: newProduct });
});

// Middleware para manejar rutas no encontradas
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        message: 'Ruta no encontrada',
        path: req.originalUrl
    });
});

// Middleware de manejo de errores
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
    });
});

// Iniciar servidor
app.listen(PORT, '127.0.0.1', () => {
    console.log(`🚀 API de prueba corriendo en http://127.0.0.1:${PORT}`);
    console.log(`📊 Health check: http://127.0.0.1:${PORT}/api/health`);
    console.log(`👥 Usuarios: http://127.0.0.1:${PORT}/api/users`);
    console.log(`📦 Productos: http://127.0.0.1:${PORT}/api/products`);
});

// Manejo de cierre graceful
process.on('SIGTERM', () => {
    console.log('🛑 Servidor API cerrándose...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Servidor API cerrándose...');
    process.exit(0);
});
EOF

# Crear archivo de servicio systemd
print_status "Creando servicio systemd..."
cat > /etc/systemd/system/test-api.service << EOF
[Unit]
Description=Test API Server
Documentation=https://nodejs.org
After=network.target

[Service]
Environment=NODE_ENV=production
Type=simple
User=$API_USER
ExecStart=/usr/bin/node $API_DIR/server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Establecer permisos
chown -R $API_USER:$API_USER $API_DIR
chmod +x $API_DIR/server.js

# Configurar nginx como proxy reverso
print_status "Configurando nginx como proxy reverso..."
cat > /etc/nginx/sites-available/api-https << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirigir todo el tráfico HTTP a HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Incluir configuración SSL
    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    root /var/www/html;
    index index.html;

    # Logs
    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # Página principal
    location = / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy para el API
    location /api/ {
        proxy_pass http://127.0.0.1:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Archivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Actualizar página principal con información del API
print_status "Actualizando página principal..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API de Prueba - HTTPS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            padding: 2rem;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 3rem;
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        .api-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-bottom: 3rem;
        }
        .card {
            background: rgba(255,255,255,0.15);
            padding: 2rem;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        .endpoint {
            margin-bottom: 1rem;
        }
        .method {
            display: inline-block;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-weight: bold;
            margin-right: 1rem;
            font-size: 0.8rem;
        }
        .get { background: #4ade80; color: black; }
        .post { background: #fbbf24; color: black; }
        .put { background: #60a5fa; color: black; }
        .delete { background: #f87171; color: black; }
        .url {
            background: rgba(0,0,0,0.3);
            padding: 0.5rem;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            word-break: break-all;
        }
        .test-section {
            background: rgba(255,255,255,0.1);
            padding: 2rem;
            border-radius: 15px;
            margin-top: 2rem;
        }
        button {
            background: #4ade80;
            color: black;
            border: none;
            padding: 1rem 2rem;
            border-radius: 25px;
            font-weight: bold;
            cursor: pointer;
            margin: 0.5rem;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .response {
            background: rgba(0,0,0,0.3);
            padding: 1rem;
            border-radius: 10px;
            margin-top: 1rem;
            max-height: 400px;
            overflow-y: auto;
        }
        pre {
            white-space: pre-wrap;
            font-size: 0.9rem;
        }
        .status { margin: 1rem 0; }
        .lock { font-size: 3rem; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="lock">🔒🚀</div>
            <h1>API de Prueba - HTTPS</h1>
            <div class="status">Servidor nginx + Node.js funcionando</div>
        </div>

        <div class="api-grid">
            <div class="card">
                <h2>👥 Usuarios API</h2>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/users</div>
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/users/:id</div>
                </div>
                <div class="endpoint">
                    <span class="method post">POST</span>
                    <div class="url">/api/users</div>
                </div>
                <div class="endpoint">
                    <span class="method put">PUT</span>
                    <div class="url">/api/users/:id</div>
                </div>
                <div class="endpoint">
                    <span class="method delete">DELETE</span>
                    <div class="url">/api/users/:id</div>
                </div>
            </div>

            <div class="card">
                <h2>📦 Productos API</h2>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/products</div>
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/products/:id</div>
                </div>
                <div class="endpoint">
                    <span class="method post">POST</span>
                    <div class="url">/api/products</div>
                </div>
                <p><strong>Filtros:</strong> ?category=X&minPrice=Y&maxPrice=Z</p>
            </div>

            <div class="card">
                <h2>🔧 Sistema</h2>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/health</div>
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/info</div>
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <div class="url">/api/</div>
                </div>
            </div>
        </div>

        <div class="test-section">
            <h2>🧪 Pruebas Rápidas</h2>
            <button onclick="testEndpoint('/api/health')">Health Check</button>
            <button onclick="testEndpoint('/api/users')">Ver Usuarios</button>
            <button onclick="testEndpoint('/api/products')">Ver Productos</button>
            <button onclick="testEndpoint('/api/info')">Info del API</button>
            
            <div class="response" id="response" style="display:none;">
                <h3>Respuesta:</h3>
                <pre id="responseContent"></pre>
            </div>
        </div>
    </div>

    <script>
        async function testEndpoint(endpoint) {
            const responseDiv = document.getElementById('response');
            const responseContent = document.getElementById('responseContent');
            
            try {
                responseDiv.style.display = 'block';
                responseContent.textContent = 'Cargando...';
                
                const response = await fetch(endpoint);
                const data = await response.json();
                
                responseContent.textContent = JSON.stringify(data, null, 2);
            } catch (error) {
                responseContent.textContent = `Error: ${error.message}`;
            }
        }
    </script>
</body>
</html>
EOF

# Habilitar nueva configuración de nginx
rm -f /etc/nginx/sites-enabled/default-https
ln -sf /etc/nginx/sites-available/api-https /etc/nginx/sites-enabled/

# Verificar configuración de nginx
if nginx -t; then
    print_success "Configuración de nginx válida"
else
    print_error "Error en la configuración de nginx"
    exit 1
fi

# Habilitar y iniciar servicios
print_status "Habilitando servicios..."
systemctl daemon-reload
systemctl enable test-api
systemctl start test-api
systemctl reload nginx

# Esperar a que el API inicie
sleep 3

# Verificar que los servicios estén funcionando
if systemctl is-active --quiet test-api && systemctl is-active --quiet nginx; then
    print_success "Todos los servicios están funcionando correctamente"
else
    print_error "Algunos servicios no están funcionando"
    systemctl status test-api
    exit 1
fi

# Mostrar información final
echo ""
echo "=========================================="
print_success "¡API de prueba configurada exitosamente!"
echo "=========================================="
echo ""
echo "URLs disponibles:"
echo "----------------"
echo "🌐 Interfaz web: https://$DOMAIN"
echo "🔧 Health check: https://$DOMAIN/api/health"
echo "👥 Usuarios: https://$DOMAIN/api/users"
echo "📦 Productos: https://$DOMAIN/api/products"
echo ""
echo "Comandos útiles:"
echo "---------------"
echo "Ver estado API: systemctl status test-api"
echo "Ver logs API: journalctl -u test-api -f"
echo "Reiniciar API: systemctl restart test-api"
echo "Ver logs nginx: tail -f /var/log/nginx/api_access.log"
echo ""
echo "Pruebas con curl:"
echo "----------------"
echo "curl -k https://localhost/api/health"
echo "curl -k https://localhost/api/users"
echo "curl -k https://localhost/api/products"
echo ""
echo "Crear usuario:"
echo 'curl -k -X POST https://localhost/api/users \'
echo '  -H "Content-Type: application/json" \'
echo '  -d {"name":"Test User","email":"test@example.com","city":"Pasto"}'
echo ""
print_warning "El API corre en el puerto $API_PORT internamente"
print_warning "nginx actúa como proxy reverso con HTTPS"
