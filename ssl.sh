#!/bin/bash

# Funktion zur Installation von NGINX und notwendigen Paketen
install_nginx() {
    echo "Updating system and installing NGINX and apache2-utils..."
    apt-get update && apt-get install -y nginx apache2-utils
}

# Funktion zur Installation von Certbot und Generierung des SSL-Zertifikats
install_certbot() {
    local domain=$1
    local email=$2
    echo "Installing certbot and generating SSL certificate for $domain..."
    apt-get update && apt-get install -y certbot python3-certbot-nginx
    certbot -d "$domain" --non-interactive --agree-tos -m "$email" --nginx
}

# Funktion zur Freigabe der Ports mit ufw
configure_ufw() {
    echo "Configuring UFW to allow necessary ports..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "Ports 80 (HTTP) and 443 (HTTPS) have been allowed through UFW."
}

# Funktion zur Anzeige der benötigten Ports, falls eine andere Firewall verwendet wird
display_ports_info() {
    whiptail --title "Required Ports" --msgbox "Please ensure the following ports are allowed through your firewall:\n\nHTTP: 80\nHTTPS: 443" 12 78
}

# Funktion zur Erstellung der NGINX-Konfigurationsdatei
setup_nginx_config() {
    local domain=$1
    local config_path="/etc/nginx/sites-available/$domain"
    local photoprism_address=$2

    echo "Creating NGINX configuration for $domain..."
    cat > "$config_path" <<EOF
# PhotoPrism NGINX configuration with WebSocket support
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

    client_max_body_size 20G;

    location / {
        proxy_pass http://$photoprism_address;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    ln -s "$config_path" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

# Hauptskript mit whiptail für Benutzereingaben
main() {
    DOMAIN=$(whiptail --inputbox "Enter your domain name for PhotoPrism:" 8 78 photoprism.example.com --title "Domain Setup" 3>&1 1>&2 2>&3)
    EMAIL=$(whiptail --inputbox "Enter your email address for SSL certificate registration:" 8 78 --title "Email Address" 3>&1 1>&2 2>&3)
    PHOTOPRISM_ADDRESS=$(whiptail --inputbox "Enter your PhotoPrism IP address or DNS name:" 8 78 docker.homenet:2342 --title "PhotoPrism Address" 3>&1 1>&2 2>&3)

    if (whiptail --title "Firewall Configuration" --yesno "Do you want to configure UFW to allow necessary ports automatically?" 8 78); then
        configure_ufw
    else
        display_ports_info
    fi

    install_nginx
    install_certbot "$DOMAIN" "$EMAIL"
    setup_nginx_config "$DOMAIN" "$PHOTOPRISM_ADDRESS"

    echo "Setup completed. Access PhotoPrism at https://$DOMAIN"
}

main
