#!/bin/bash

# Funktion zur Installation von NGINX und notwendigen Paketen
install_nginx() {
    echo "Updating system and installing NGINX and apache2-utils..."
    apt-get update && apt-get install -y nginx apache2-utils
}

# Funktion zur Installation von Certbot und Generierung des SSL-Zertifikats
install_certbot() {
    local domain=$1
    echo "Installing certbot and generating SSL certificate for $domain..."
    apt-get update && apt-get install -y certbot python3-certbot-nginx
    certbot -d "$domain" --non-interactive --agree-tos -m your-email@example.com --nginx
}

# Funktion zur Erstellung der NGINX-Konfigurationsdatei
setup_nginx_config() {
    local domain=$1
    local config_path="/etc/nginx/sites-available/$domain"
    local photoprism_address=$2

    echo "Creating NGINX configuration for $domain..."
    cat > "$config_path" <<EOF
# PhotoPrism NGINX configuration
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!RC4:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS;
    add_header Strict-Transport-Security "max-age=172800; includeSubdomains";

    location / {
        proxy_pass http://$photoprism_address;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -s "$config_path" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

# Hauptskript mit whiptail für Benutzereingaben
main() {
    DOMAIN=$(whiptail --inputbox "Enter your domain name for PhotoPrism:" 8 78 photoprism.example.com --title "Domain Setup" 3>&1 1>&2 2>&3)
    PHOTOPRISM_ADDRESS=$(whiptail --inputbox "Enter your PhotoPrism IP address or DNS name:" 8 78 docker.homenet:2342 --title "PhotoPrism Address" 3>&1 1>&2 2>&3)

    install_nginx
    install_certbot "$DOMAIN"
    setup_nginx_config "$DOMAIN" "$PHOTOPRISM_ADDRESS"

    echo "Setup completed. Access PhotoPrism at https://$DOMAIN"
}

main
