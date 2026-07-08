#!/bin/bash

echo "=== VICIdial SSL Auto Setup by Debjit ==="

# 1. Ask for domain and IP
read -p "Enter your VICIdial domain (e.g., demo1211.beltalk.live): " DOMAIN
read -p "Enter your Dialer Public IP : " DIALER_IP

# 2. Set SSL cert and key paths
SSL_CRT="/etc/apache2/ssl.crt/fullchain.crt"
SSL_KEY="/etc/apache2/ssl.key/_.beltalk.live.key"

# 3. Validate SSL files
if [[ ! -s "$SSL_CRT" || ! -s "$SSL_KEY" ]]; then
  echo "❌ SSL cert or key file is missing or empty!"
  echo "Expected:"
  echo "  - $SSL_CRT"
  echo "  - $SSL_KEY"
  exit 1
fi

CRT_FILE=$(basename "$SSL_CRT")
KEY_FILE=$(basename "$SSL_KEY")

# 4. Update /etc/hosts
sed -i "/[[:space:]]$DOMAIN$/d" /etc/hosts
sed -i "/^$DIALER_IP[[:space:]]/d" /etc/hosts

if grep -q "^127.0.0.1" /etc/hosts; then
  awk -v ip="$DIALER_IP" -v domain="$DOMAIN" '
    /^127.0.0.1/ {
      print $0
      print ip, domain
      next
    }
    { print }
  ' /etc/hosts > /tmp/hosts.tmp && mv /tmp/hosts.tmp /etc/hosts
  echo "✅ Inserted $DIALER_IP $DOMAIN just below 127.0.0.1 in /etc/hosts"
else
  echo "127.0.0.1 localhost" >> /etc/hosts
  echo "$DIALER_IP $DOMAIN" >> /etc/hosts
  echo "✅ Added loopback and domain to /etc/hosts"
fi

# 5. Update /etc/hostname
echo "$DOMAIN" > /etc/hostname
echo "✅ Set hostname to $DOMAIN"

# 6. Update default-server.conf
DEF_CONF="/etc/apache2/default-server.conf"
if grep -q "$DOMAIN" "$DEF_CONF"; then
  echo "✅ default-server.conf already configured"
else
  cat <<EOF >> "$DEF_CONF"

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
  echo "✅ Appended HTTPS redirect to $DEF_CONF"
fi

# 7. Update all vhosts in /etc/apache2/vhosts.d/
for vhost in /etc/apache2/vhosts.d/*.conf; do
  if grep -q "SSLCertificateFile" "$vhost"; then
    sed -i "s|^.*SSLCertificateFile.*|SSLCertificateFile /etc/apache2/ssl.crt/$CRT_FILE|" "$vhost"
    echo "✅ Patched SSLCertificateFile in $vhost"
  fi
  if grep -q "SSLCertificateKeyFile" "$vhost"; then
    sed -i "s|^.*SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/apache2/ssl.key/$KEY_FILE|" "$vhost"
    echo "✅ Patched SSLCertificateKeyFile in $vhost"
  fi
done

# 8. Patch ssl-global.conf
GLOBAL_CONF="/etc/apache2/ssl-global.conf"
if grep -q "$CRT_FILE" "$GLOBAL_CONF"; then
  echo "✅ ssl-global.conf already configured"
else
  sed -i "/#.*SSLCertificateFile.*/a SSLCertificateFile /etc/apache2/ssl.crt/$CRT_FILE\nSSLCertificateKeyFile /etc/apache2/ssl.key/$KEY_FILE" "$GLOBAL_CONF"
  echo "✅ Patched $GLOBAL_CONF with cert and key"
fi

# 9. Modify Asterisk http.conf
AST_HTTP="/etc/asterisk/http.conf"

if grep -q "^;*tlsbindaddr=" "$AST_HTTP"; then
  sed -i "s|^;*tlsbindaddr=.*|tlsbindaddr=$DIALER_IP:8089|" "$AST_HTTP"
  echo "✅ Replaced tlsbindaddr in $AST_HTTP"
else
  echo "⚠️ tlsbindaddr not found in $AST_HTTP — add manually if needed"
fi

if grep -q "^;*tlscertfile=" "$AST_HTTP"; then
  sed -i "s|^;*tlscertfile=.*|tlscertfile=/etc/apache2/ssl.crt/$CRT_FILE|" "$AST_HTTP"
  echo "✅ Replaced tlscertfile in $AST_HTTP"
fi

if grep -q "^;*tlsprivatekey=" "$AST_HTTP"; then
  sed -i "s|^;*tlsprivatekey=.*|tlsprivatekey=/etc/apache2/ssl.key/$KEY_FILE|" "$AST_HTTP"
  echo "✅ Replaced tlsprivatekey in $AST_HTTP"
fi

# 10. Restart Apache and HTTPD
echo "🔁 Restarting apache2..."
systemctl restart apache2 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ apache2 failed to restart. Run: systemctl status apache2 -l"
else
  echo "✅ apache2 restarted successfully."
fi

echo "🔁 Restarting httpd..."
systemctl restart httpd 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ httpd failed to restart. Run: systemctl status httpd -l"
else
  echo "✅ httpd restarted successfully."
fi

echo "🎉 All configuration steps completed successfully."

# 11. Reboot confirmation
read -p "🔄 Do you want to reboot the server now? [y/N]: " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
  echo "♻️ Rebooting now..."
  reboot
else
  echo "⏹️ Skipped reboot. Please reboot manually later if required."
fi
