#!/bin/bash

# Script para exponer el API hacia afuera manteniendo seguridad
# El API sigue en localhost, nginx actúa como proxy público

set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Este script debe ejecutarse como root (sudo)"
   exit 1
fi

echo "=========================================="
echo "🌐 Exponiendo API hacia afuera"
echo "=========================================="

# Obtener IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_OR_IP="_"  # Acepta cualquier dominio/IP

print_status "IP del servidor detectada: $SERVER_IP"

# Crear nueva configuración nginx para acceso externo
print_status "Configurando nginx para acceso externo..."
cat > /etc/nginx/sites-available/api-external << EOF
# Redirigir HTTP a HTTPS
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN_OR_IP;
    
    # Redirigir todo el tráfico HTTP a HTTPS
    return 301 https://\$host\$request_uri;
}

# Servidor HTTPS principal
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name $DOMAIN_OR_IP;

    # Configuración SSL
    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    root /var/www/html;
    index index.html;

    # Logs
    access_log /var/log/nginx/external_api_access.log;
    error_log /var/log/nginx/external_api_error.log;

    # Página principal
    location = / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy para el API - Mantiene API en localhost por seguridad
    location /api/ {
        # Limitar acceso si es necesario
        # allow 192.168.1.0/24;  # Solo red local
        # deny all;
        
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Headers de seguridad adicionales
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Rate limiting (opcional)
        # limit_req zone=api burst=10 nodelay;
    }

    # Archivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff" always;
    }

    # Bloquear archivos sensibles
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(log|conf)$ {
        deny all;
    }
}
EOF

# Crear configuración de rate limiting (opcional pero recomendada)
print_status "Configurando rate limiting..."
cat > /etc/nginx/conf.d/rate_limiting.conf << 'EOF'
# Rate limiting para API
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;
}
EOF

# Reemplazar configuración actual
rm -f /etc/nginx/sites-enabled/*
ln -sf /etc/nginx/sites-available/api-external /etc/nginx/sites-enabled/

# Actualizar página principal con información de acceso externo
print_status "Actualizando página principal..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API de Prueba - Acceso Externo</title>
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
        .access-info {
            background: rgba(74, 222, 128, 0.2);
            padding: 2rem;
            border-radius: 15px;
            margin-bottom: 2rem;
            border: 2px solid #4ade80;
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
        .lock { font-size: 3rem; margin-bottom: 1rem; }
        .external-icon { font-size: 2rem; color: #4ade80; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="lock">🔒🌐</div>
            <h1>API de Prueba - Acceso Externo</h1>
            <div class="status">Servidor nginx + Node.js accesible externamente</div>
        </div>

        <div class="access-info">
            <div class="external-icon">🌍</div>
            <h2>¡API disponible externamente!</h2>
            <p><strong>IP del servidor:</strong> $SERVER_IP</p>
            <p><strong>Acceso externo:</strong> https://$SERVER_IP/</p>
            <p><strong>API externo:</strong> https://$SERVER_IP/api/</p>
            <p><strong>Nota:</strong> El certificado es autofirmado, acepta la advertencia del navegador</p>
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

        <div class="card" style="margin-top: 2rem;">
            <h3>🔧 Comandos curl externos</h3>
            <div class="url">curl -k https://$SERVER_IP/api/health</div>
            <div class="url">curl -k https://$SERVER_IP/api/users</div>
            <div class="url">curl -k https://$SERVER_IP/api/products</div>
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
                responseContent.textContent = \`Error: \${error.message}\`;
            }
        }
    </script>
</body>
</html>
EOF

# Verificar configuración de nginx
print_status "Verificando configuración de nginx..."
if nginx -t; then
    print_success "Configuración de nginx válida"
else
    echo -e "${RED}[ERROR]${NC} Error en la configuración de nginx"
    exit 1
fi

# Configurar firewall para permitir acceso externo
if command -v ufw > /dev/null; then
    print_status "Configurando firewall..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    print_success "Puertos 80 y 443 abiertos en firewall"
fi

# Reiniciar nginx
print_status "Reiniciando nginx..."
systemctl reload nginx

# Verificar que nginx esté funcionando
if systemctl is-active --quiet nginx; then
    print_success "nginx funcionando correctamente"
else
    echo -e "${RED}[ERROR]${NC} nginx no está funcionando"
    exit 1
fi

# Mostrar información final
echo ""
echo "=========================================="
print_success "¡API expuesta exitosamente hacia afuera!"
echo "=========================================="
echo ""
echo "🌐 Acceso externo disponible en:"
echo "--------------------------------"
echo "🖥️  Interfaz web: https://$SERVER_IP/"
echo "🔧 Health check: https://$SERVER_IP/api/health"
echo "👥 Usuarios: https://$SERVER_IP/api/users"
echo "📦 Productos: https://$SERVER_IP/api/products"
echo ""
echo "🧪 Prueba desde otra máquina:"
echo "-----------------------------"
echo "curl -k https://$SERVER_IP/api/health"
echo "curl -k https://$SERVER_IP/api/users"
echo ""
print_warning "IMPORTANTE:"
print_warning "- El certificado es autofirmado (advertencia en navegador)"
print_warning "- El API backend sigue en localhost (más seguro)"
print_warning "- nginx actúa como proxy público"
echo ""
print_success "¡Ya puedes acceder desde cualquier dispositivo en la red!"#!/bin/bash

# Script para exponer el API hacia afuera manteniendo seguridad
# El API sigue en localhost, nginx actúa como proxy público

set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Este script debe ejecutarse como root (sudo)"
   exit 1
fi

echo "=========================================="
echo "🌐 Exponiendo API hacia afuera"
echo "=========================================="

# Obtener IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_OR_IP="_"  # Acepta cualquier dominio/IP

print_status "IP del servidor detectada: $SERVER_IP"

# Crear nueva configuración nginx para acceso externo
print_status "Configurando nginx para acceso externo..."
cat > /etc/nginx/sites-available/api-external << EOF
# Redirigir HTTP a HTTPS
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN_OR_IP;
    
    # Redirigir todo el tráfico HTTP a HTTPS
    return 301 https://\$host\$request_uri;
}

# Servidor HTTPS principal
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name $DOMAIN_OR_IP;

    # Configuración SSL
    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    root /var/www/html;
    index index.html;

    # Logs
    access_log /var/log/nginx/external_api_access.log;
    error_log /var/log/nginx/external_api_error.log;

    # Página principal
    location = / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy para el API - Mantiene API en localhost por seguridad
    location /api/ {
        # Limitar acceso si es necesario
        # allow 192.168.1.0/24;  # Solo red local
        # deny all;
        
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Headers de seguridad adicionales
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Rate limiting (opcional)
        # limit_req zone=api burst=10 nodelay;
    }

    # Archivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff" always;
    }

    # Bloquear archivos sensibles
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(log|conf)$ {
        deny all;
    }
}
EOF

# Crear configuración de rate limiting (opcional pero recomendada)
print_status "Configurando rate limiting..."
cat > /etc/nginx/conf.d/rate_limiting.conf << 'EOF'
# Rate limiting para API
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;
}
EOF

# Reemplazar configuración actual
rm -f /etc/nginx/sites-enabled/*
ln -sf /etc/nginx/sites-available/api-external /etc/nginx/sites-enabled/

# Actualizar página principal con información de acceso externo
print_status "Actualizando página principal..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API de Prueba - Acceso Externo</title>
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
        .access-info {
            background: rgba(74, 222, 128, 0.2);
            padding: 2rem;
            border-radius: 15px;
            margin-bottom: 2rem;
            border: 2px solid #4ade80;
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
        .lock { font-size: 3rem; margin-bottom: 1rem; }
        .external-icon { font-size: 2rem; color: #4ade80; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="lock">🔒🌐</div>
            <h1>API de Prueba - Acceso Externo</h1>
            <div class="status">Servidor nginx + Node.js accesible externamente</div>
        </div>

        <div class="access-info">
            <div class="external-icon">🌍</div>
            <h2>¡API disponible externamente!</h2>
            <p><strong>IP del servidor:</strong> $SERVER_IP</p>
            <p><strong>Acceso externo:</strong> https://$SERVER_IP/</p>
            <p><strong>API externo:</strong> https://$SERVER_IP/api/</p>
            <p><strong>Nota:</strong> El certificado es autofirmado, acepta la advertencia del navegador</p>
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

        <div class="card" style="margin-top: 2rem;">
            <h3>🔧 Comandos curl externos</h3>
            <div class="url">curl -k https://$SERVER_IP/api/health</div>
            <div class="url">curl -k https://$SERVER_IP/api/users</div>
            <div class="url">curl -k https://$SERVER_IP/api/products</div>
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
                responseContent.textContent = \`Error: \${error.message}\`;
            }
        }
    </script>
</body>
</html>
EOF

# Verificar configuración de nginx
print_status "Verificando configuración de nginx..."
if nginx -t; then
    print_success "Configuración de nginx válida"
else
    echo -e "${RED}[ERROR]${NC} Error en la configuración de nginx"
    exit 1
fi

# Configurar firewall para permitir acceso externo
if command -v ufw > /dev/null; then
    print_status "Configurando firewall..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    print_success "Puertos 80 y 443 abiertos en firewall"
fi

# Reiniciar nginx
print_status "Reiniciando nginx..."
systemctl reload nginx

# Verificar que nginx esté funcionando
if systemctl is-active --quiet nginx; then
    print_success "nginx funcionando correctamente"
else
    echo -e "${RED}[ERROR]${NC} nginx no está funcionando"
    exit 1
fi

# Mostrar información final
echo ""
echo "=========================================="
print_success "¡API expuesta exitosamente hacia afuera!"
echo "=========================================="
echo ""
echo "🌐 Acceso externo disponible en:"
echo "--------------------------------"
echo "🖥️  Interfaz web: https://$SERVER_IP/"
echo "🔧 Health check: https://$SERVER_IP/api/health"
echo "👥 Usuarios: https://$SERVER_IP/api/users"
echo "📦 Productos: https://$SERVER_IP/api/products"
echo ""
echo "🧪 Prueba desde otra máquina:"
echo "-----------------------------"
echo "curl -k https://$SERVER_IP/api/health"
echo "curl -k https://$SERVER_IP/api/users"
echo ""
print_warning "IMPORTANTE:"
print_warning "- El certificado es autofirmado (advertencia en navegador)"
print_warning "- El API backend sigue en localhost (más seguro)"
print_warning "- nginx actúa como proxy público"
echo ""
print_success "¡Ya puedes acceder desde cualquier dispositivo en la red!"
