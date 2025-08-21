#!/bin/bash

# Script para configurar nginx con HTTPS en Ubuntu Server
# Autor: Script automatizado
# Fecha: $(date)

set -e  # Salir si hay algún error

echo "=========================================="
echo "Configurando nginx con HTTPS en Ubuntu"
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
DOMAIN="localhost"
CERT_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/sites-available/default-https"
WEB_ROOT="/var/www/html"

# Actualizar paquetes del sistema
print_status "Actualizando paquetes del sistema..."
apt update

# Instalar nginx y openssl
print_status "Instalando nginx y openssl..."
apt install -y nginx openssl

# Crear directorio para certificados SSL
print_status "Creando directorio para certificados SSL..."
mkdir -p $CERT_DIR

# Generar certificado autofirmado
print_status "Generando certificado SSL autofirmado..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $CERT_DIR/nginx-selfsigned.key \
    -out $CERT_DIR/nginx-selfsigned.crt \
    -subj "/C=CO/ST=Narino/L=Pasto/O=TestOrg/OU=IT/CN=$DOMAIN"

# Generar parámetros DH para mayor seguridad
print_status "Generando parámetros Diffie-Hellman (esto puede tomar unos minutos)..."
openssl dhparam -out $CERT_DIR/dhparam.pem 2048

# Establecer permisos seguros para los certificados
chmod 600 $CERT_DIR/nginx-selfsigned.key
chmod 644 $CERT_DIR/nginx-selfsigned.crt
chmod 644 $CERT_DIR/dhparam.pem

# Crear configuración SSL snippet
print_status "Creando configuración SSL..."
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

# Crear página web de prueba
print_status "Creando página web de prueba..."
cat > $WEB_ROOT/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servidor HTTPS - Funcionando</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        .status {
            font-size: 1.2rem;
            margin: 1rem 0;
        }
        .lock {
            font-size: 4rem;
            color: #4ade80;
            margin-bottom: 1rem;
        }
        .info {
            background: rgba(255,255,255,0.2);
            padding: 1rem;
            border-radius: 5px;
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="lock">🔒</div>
        <h1>¡HTTPS Funcionando!</h1>
        <div class="status">Servidor nginx configurado correctamente</div>
        <div class="status">Conexión segura establecida</div>
        <div class="info">
            <strong>Información:</strong><br>
            Servidor: nginx<br>
            Protocolo: HTTPS<br>
            Certificado: Autofirmado (Prueba)<br>
            Fecha: $(date)
        </div>
    </div>
</body>
</html>
EOF

# Crear configuración del sitio nginx para HTTPS
print_status "Configurando nginx para HTTPS..."
cat > $NGINX_CONF << EOF
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

    root $WEB_ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Logs
    access_log /var/log/nginx/https_access.log;
    error_log /var/log/nginx/https_error.log;

    # Configuraciones adicionales de seguridad
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Deshabilitar sitio default y habilitar el nuevo
print_status "Configurando sitios nginx..."
rm -f /etc/nginx/sites-enabled/default
ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

# Verificar configuración de nginx
print_status "Verificando configuración de nginx..."
if nginx -t; then
    print_success "Configuración de nginx válida"
else
    print_error "Error en la configuración de nginx"
    exit 1
fi

# Configurar firewall (si ufw está activo)
if ufw status | grep -q "Status: active"; then
    print_status "Configurando firewall..."
    ufw allow 'Nginx Full'
    ufw delete allow 'Nginx HTTP' 2>/dev/null || true
fi

# Habilitar y reiniciar nginx
print_status "Habilitando y reiniciando nginx..."
systemctl enable nginx
systemctl restart nginx

# Verificar que nginx esté funcionando
if systemctl is-active --quiet nginx; then
    print_success "nginx está funcionando correctamente"
else
    print_error "nginx no está funcionando"
    exit 1
fi

# Mostrar información final
echo ""
echo "=========================================="
print_success "¡Configuración completada exitosamente!"
echo "=========================================="
echo ""
echo "Información del servidor:"
echo "------------------------"
echo "URL HTTPS: https://$DOMAIN"
echo "URL HTTP: http://$DOMAIN (redirige a HTTPS)"
echo "Directorio web: $WEB_ROOT"
echo "Certificados SSL: $CERT_DIR"
echo "Logs nginx: /var/log/nginx/"
echo ""
echo "Comandos útiles:"
echo "---------------"
echo "Estado nginx: systemctl status nginx"
echo "Reiniciar nginx: systemctl restart nginx"
echo "Ver logs: tail -f /var/log/nginx/https_access.log"
echo "Probar configuración: nginx -t"
echo ""
print_warning "IMPORTANTE: Este certificado es autofirmado y solo para pruebas."
print_warning "Los navegadores mostrarán una advertencia de seguridad."
print_warning "Para producción, usa certificados de Let's Encrypt o una CA válida."
echo ""
echo "Para probar:"
echo "curl -k https://localhost"
echo "curl -k https://$(hostname -I | awk '{print $1}')"
