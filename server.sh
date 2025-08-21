#!/bin/bash
set -e

# === Variables ===
APP_DIR="/opt/fastapi-tutorial"
DOMAIN="localhost"
PORT=8000
CERT_DIR="/etc/ssl/fastapi"

# === Actualizar paquetes ===
sudo apt update && sudo apt upgrade -y

# === Instalar dependencias ===
sudo apt install -y python3 python3-pip python3-venv git openssl

# === Clonar el repositorio ===
if [ ! -d "$APP_DIR" ]; then
  sudo git clone https://github.com/pixegami/fastapi-tutorial.git "$APP_DIR"
fi

# === Crear entorno virtual ===
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate

# === Instalar dependencias ===
pip install --upgrade pip
pip install -r requirements.txt uvicorn[standard]

# === Crear certificados autofirmados ===
if [ ! -d "$CERT_DIR" ]; then
  sudo mkdir -p "$CERT_DIR"
  sudo openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$CERT_DIR/fastapi.key" \
    -out "$CERT_DIR/fastapi.crt" \
    -subj "/CN=$DOMAIN"
fi

# === Crear servicio systemd ===
SERVICE_FILE="/etc/systemd/system/fastapi.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=FastAPI HTTPS Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/uvicorn app.main:app \\
  --host 0.0.0.0 \\
  --port $PORT \\
  --ssl-keyfile $CERT_DIR/fastapi.key \\
  --ssl-certfile $CERT_DIR/fastapi.crt
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# === Recargar systemd y habilitar servicio ===
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable fastapi
sudo systemctl restart fastapi

echo "✅ API FastAPI montada en https://$DOMAIN:$PORT"
