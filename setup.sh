#!/bin/bash

# Ask for domain
read -p "Enter your VICIdial domain (e.g., vici3.viciant.online): " DOMAIN

# Ask for dialer IP
read -p "Enter the Dialer IP (e.g., 10.0.0.10): " DIALER_IP

# Auto-detect the first .crt and .key files in the directories
SSL_CRT=$(ls /etc/apache2/ssl.crt/*.crt 2>/dev/null | head -n1)
SSL_KEY=$(ls /etc/apache2/ssl.key/*.key 2>/dev/null | head -n1)

if [[ -z "$SSL_CRT" || -z "$SSL_KEY" ]]; then
  echo "Error: SSL certificate or key not found in expected directories."
  exit 1
fi

# Extract filenames only
CRT_FILE=$(basename "$SSL_CRT")
KEY_FILE=$(basename "$SSL_KEY")

# 1. Update /etc/hosts
echo "$DIALER_IP $DOMAIN" >> /etc/hosts

# 2. Update /etc/hostname
echo "$DOMAIN" > /etc/hostname

# 3. Edit /etc/apache2/default-server.conf
cat <<EOF >> /etc/apache2/default-server.conf

# Secure redirect
<VirtualHost *:80>
   ServerName $DOMAIN
   DocumentRoot /srv/www/htdocs
   Redirect permanent / https://$DOMAIN/
</VirtualHost>

<VirtualHost _default_:443>
   ServerName $DOMAIN
   DocumentRoot "/srv/www/htdocs"
   SSLEngine On
</VirtualHost>
EOF

# 4. Edit vhosts.d/0000-*-default-ssl.conf
SSL_CONF=$(find /etc/apache2/vhosts.d/ -name "0000-*-default-ssl.conf" | head -n1)
if [[ -n "$SSL_CONF" ]]; then
  sed -i "/SSLEngine On/a SSLCertificateFile /etc/apache2/ssl.crt/$CRT_FILE\nSSLCertificateKeyFile /etc/apache2/ssl.key/$KEY_FILE" "$SSL_CONF"
fi

# 5. Edit /etc/apache2/ssl-global.conf
sed -i "/#.*SSLCertificateFile.*/a SSLCertificateFile /etc/apache2/ssl.crt/$CRT_FILE\nSSLCertificateKeyFile /etc/apache2/ssl.key/$KEY_FILE" /etc/apache2/ssl-global.conf

# 6. Configure Asterisk http.conf (ONLY TLS settings)
AST_HTTP_CONF="/etc/asterisk/http.conf"

# Ensure lines exist or append them
grep -q '^tlsbindaddr=' "$AST_HTTP_CONF" && \
  sed -i "s|^tlsbindaddr=.*|tlsbindaddr=$DIALER_IP:8089|" "$AST_HTTP_CONF" || \
  echo "tlsbindaddr=$DIALER_IP:8089" >> "$AST_HTTP_CONF"

grep -q '^tlscertfile=' "$AST_HTTP_CONF" && \
  sed -i "s|^tlscertfile=.*|tlscertfile=/etc/apache2/ssl.crt/$CRT_FILE|" "$AST_HTTP_CONF" || \
  echo "tlscertfile=/etc/apache2/ssl.crt/$CRT_FILE" >> "$AST_HTTP_CONF"

grep -q '^tlsprivatekey=' "$AST_HTTP_CONF" && \
  sed -i "s|^tlsprivatekey=.*|tlsprivatekey=/etc/apache2/ssl.key/$KEY_FILE|" "$AST_HTTP_CONF" || \
  echo "tlsprivatekey=/etc/apache2/ssl.key/$KEY_FILE" >> "$AST_HTTP_CONF"

# 7. Restart Services
echo "Restarting Apache and HTTPD services..."
systemctl restart apache2
systemctl status apache2 --no-pager

systemctl restart httpd
systemctl status httpd --no-pager

echo "✅ Configuration complete. You may now reboot the system if needed."
