#!/bin/bash
set -e

# ===============================
# 1. Actualizar sistema
# ===============================
sudo apt update && sudo apt upgrade -y

# ===============================
# 2. Instalar dependencias
# ===============================
sudo apt install -y python3 python3-pip python3-venv git nginx openssl

# ===============================
# 3. Clonar FastAPI ejemplo
# ===============================
cd /opt
sudo git clone https://github.com/tiangolo/fastapi fastapi-example
cd fastapi-example/examples/tutorial

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn

# ===============================
# 4. Crear servicio systemd para Uvicorn
# ===============================
SERVICE_FILE=/etc/systemd/system/fastapi.service
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=FastAPI application with Uvicorn
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/fastapi-example/examples/tutorial
Environment=\"PATH=/opt/fastapi-example/examples/tutorial/venv/bin\"
ExecStart=/opt/fastapi-example/examples/tutorial/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Habilitar y arrancar servicio
sudo systemctl daemon-reexec
sudo systemctl enable fastapi
sudo systemctl start fastapi

# ===============================
# 5. Crear certificado SSL autofirmado
# ===============================
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/C=CO/ST=Nariño/L=SanJuan/O=Test/OU=Dev/CN=miproyecto.local" \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt

# ===============================
# 6. Configurar Nginx
# ===============================
NGINX_FILE=/etc/nginx/sites-available/fastapi
sudo bash -c "cat > $NGINX_FILE" <<EOF
server {
    listen 80;
    server_name miproyecto.local;

    # Redirigir todo HTTP a HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name miproyecto.local;

    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Activar configuración
sudo ln -sf /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "===================================="
echo "🚀 API FastAPI instalada con HTTPS"
echo "Accede en: https://miproyecto.local"
echo "Documentación: https://miproyecto.local/docs"
echo "===================================="
#!/bin/bash
set -e

# ===============================
# 1. Actualizar sistema
# ===============================
sudo apt update && sudo apt upgrade -y

# ===============================
# 2. Instalar dependencias
# ===============================
sudo apt install -y python3 python3-pip python3-venv git nginx openssl

# ===============================
# 3. Clonar FastAPI ejemplo
# ===============================
cd /opt
sudo git clone https://github.com/tiangolo/fastapi fastapi-example
cd fastapi-example/examples/tutorial

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn

# ===============================
# 4. Crear servicio systemd para Uvicorn
# ===============================
SERVICE_FILE=/etc/systemd/system/fastapi.service
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=FastAPI application with Uvicorn
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/fastapi-example/examples/tutorial
Environment=\"PATH=/opt/fastapi-example/examples/tutorial/venv/bin\"
ExecStart=/opt/fastapi-example/examples/tutorial/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Habilitar y arrancar servicio
sudo systemctl daemon-reexec
sudo systemctl enable fastapi
sudo systemctl start fastapi

# ===============================
# 5. Crear certificado SSL autofirmado
# ===============================
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/C=CO/ST=Nariño/L=SanJuan/O=Test/OU=Dev/CN=miproyecto.local" \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt

# ===============================
# 6. Configurar Nginx
# ===============================
NGINX_FILE=/etc/nginx/sites-available/fastapi
sudo bash -c "cat > $NGINX_FILE" <<EOF
server {
    listen 80;
    server_name miproyecto.local;

    # Redirigir todo HTTP a HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name miproyecto.local;

    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Activar configuración
sudo ln -sf /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "===================================="
echo "🚀 API FastAPI instalada con HTTPS"
echo "Accede en: https://miproyecto.local"
echo "Documentación: https://miproyecto.local/docs"
echo "===================================="
