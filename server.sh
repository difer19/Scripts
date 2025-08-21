#!/bin/bash
set -e

# ===========================
# Actualización del sistema
# ===========================
sudo apt update && sudo apt upgrade -y

# ===========================
# Instalación de dependencias
# ===========================
sudo apt install -y python3 python3-venv python3-pip git nginx ufw

# ===========================
# Clonar el repositorio de ejemplo
# ===========================
cd /opt
sudo git clone https://github.com/pixegami/fastapi-tutorial.git
sudo chown -R $USER:$USER fastapi-tutorial
cd fastapi-tutorial

# ===========================
# Crear entorno virtual
# ===========================
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt uvicorn gunicorn

# ===========================
# Crear servicio systemd para FastAPI
# ===========================
SERVICE_FILE=/etc/systemd/system/fastapi.service

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=FastAPI App
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=/opt/fastapi-tutorial
Environment=\"PATH=/opt/fastapi-tutorial/venv/bin\"
ExecStart=/opt/fastapi-tutorial/venv/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app --bind 127.0.0.1:8000

[Install]
WantedBy=multi-user.target
EOL

# ===========================
# Recargar systemd y habilitar servicio
# ===========================
sudo systemctl daemon-reload
sudo systemctl enable fastapi
sudo systemctl start fastapi

# ===========================
# Configuración de Nginx con HTTPS
# ===========================
SSL_DIR=/etc/ssl/fastapi
sudo mkdir -p $SSL_DIR

# Generar certificado autofirmado
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $SSL_DIR/fastapi.key \
  -out $SSL_DIR/fastapi.crt \
  -subj "/C=CO/ST=Valle/L=Cali/O=Test/OU=IT/CN=fastapi.local"

# Crear configuración de Nginx
NGINX_CONF=/etc/nginx/sites-available/fastapi
sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     $SSL_DIR/fastapi.crt;
    ssl_certificate_key $SSL_DIR/fastapi.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Redirigir HTTP a HTTPS
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOL

# Activar sitio y reiniciar nginx
sudo ln -s /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# ===========================
# Configuración del firewall
# ===========================
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo "======================================"
echo " FastAPI está corriendo en https://<IP-DE-TU-SERVIDOR>"
echo " Certificado autofirmado (acepta la advertencia en el navegador)."
echo "======================================"
