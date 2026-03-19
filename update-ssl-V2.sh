#!/bin/bash

# Configuration
SOURCE_DIR="/root/Vicidial11-auto-setup-ssl/Updated-ssl-2026"
CRT_DEST="/etc/apache2/ssl.crt"
KEY_DEST="/etc/apache2/ssl.key"

CRT_FILE="star_beltalk_live.crt"
KEY_FILE="_.beltalk.live.key"

echo "--- Starting SSL Certificate Update ---"

# 1. Backup old files
echo "Backing up existing files..."
if [ -f "$CRT_DEST/$CRT_FILE" ]; then
    mv "$CRT_DEST/$CRT_FILE" "$CRT_DEST/$CRT_FILE.bkp"
    echo "Backed up CRT to $CRT_FILE.bkp"
fi

if [ -f "$KEY_DEST/$KEY_FILE" ]; then
    mv "$KEY_DEST/$KEY_FILE" "$KEY_DEST/$KEY_FILE.bkp"
    echo "Backed up KEY to $KEY_FILE.bkp"
fi

# 2. Copy new files
echo "Copying new certificates..."
if [ -f "$SOURCE_DIR/$CRT_FILE" ] && [ -f "$SOURCE_DIR/$KEY_FILE" ]; then
    cp "$SOURCE_DIR/$CRT_FILE" "$CRT_DEST/"
    cp "$SOURCE_DIR/$KEY_FILE" "$KEY_DEST/"
    echo "New files copied successfully."
else
    echo "ERROR: New certificate files not found in $SOURCE_DIR"
    exit 1
fi

# 3. Reload Services
echo "Reloading Web Servers and Asterisk..."
systemctl reload httpd && systemctl reload apache2

if [ $? -eq 0 ]; then
    echo "Apache/HTTPD reloaded successfully."
else
    echo "Warning: There was an issue reloading Apache/HTTPD."
fi

asterisk -rx "module reload http"
echo "Asterisk HTTPD module reloaded."

echo "--- Process Complete ---"
