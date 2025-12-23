#!/bin/bash
#===============================================================================
# Full Email System Backup Script
# Creates a complete backup of all configurations and data
# Run on: Home Server
#===============================================================================

set -e

# Configuration
BACKUP_DIR="/var/backups/mail-system"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mail-system-backup-$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "=========================================="
echo "  Email System Full Backup"
echo "  Date: $(date)"
echo "=========================================="

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo "[1/8] Backing up Postfix configuration..."
mkdir -p "$BACKUP_PATH/postfix"
cp -r /etc/postfix/* "$BACKUP_PATH/postfix/"

echo "[2/8] Backing up Dovecot configuration..."
mkdir -p "$BACKUP_PATH/dovecot"
cp -r /etc/dovecot/* "$BACKUP_PATH/dovecot/"

echo "[3/8] Backing up Apache configuration..."
mkdir -p "$BACKUP_PATH/apache2"
cp -r /etc/apache2/sites-available/* "$BACKUP_PATH/apache2/"
cp /etc/apache2/ports.conf "$BACKUP_PATH/apache2/"
cp -r /etc/apache2/conf-available/z-push*.conf "$BACKUP_PATH/apache2/" 2>/dev/null || true

echo "[4/8] Backing up Z-Push configuration..."
mkdir -p "$BACKUP_PATH/z-push"
cp -r /etc/z-push/* "$BACKUP_PATH/z-push/"

echo "[5/8] Backing up PostfixAdmin configuration and database..."
mkdir -p "$BACKUP_PATH/postfixadmin"
cp /etc/postfixadmin/config.local.php "$BACKUP_PATH/postfixadmin/"
cp /var/lib/postfixadmin/postfixadmin.db "$BACKUP_PATH/postfixadmin/"

echo "[6/8] Backing up Roundcube configuration and database..."
mkdir -p "$BACKUP_PATH/roundcube"
cp /var/www/html/roundcube/config/config.inc.php "$BACKUP_PATH/roundcube/" 2>/dev/null || \
cp /etc/roundcube/config.inc.php "$BACKUP_PATH/roundcube/" 2>/dev/null || true
cp /var/lib/roundcube/roundcube.db "$BACKUP_PATH/roundcube/" 2>/dev/null || true

echo "[7/8] Backing up WireGuard configuration..."
mkdir -p "$BACKUP_PATH/wireguard"
cp /etc/wireguard/wg0.conf "$BACKUP_PATH/wireguard/"

echo "[8/8] Backing up custom scripts and cron jobs..."
mkdir -p "$BACKUP_PATH/scripts"
cp /usr/local/bin/mail-*.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
cp /usr/local/bin/update-*.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
cp /usr/local/bin/watch-*.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
cp /usr/local/bin/sync-*.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
mkdir -p "$BACKUP_PATH/cron"
cp /etc/cron.d/mail-* "$BACKUP_PATH/cron/" 2>/dev/null || true
cp /etc/cron.d/welcome-* "$BACKUP_PATH/cron/" 2>/dev/null || true
cp /etc/cron.d/sync-* "$BACKUP_PATH/cron/" 2>/dev/null || true
cp /etc/cron.d/header-* "$BACKUP_PATH/cron/" 2>/dev/null || true

# Backup SSL certificates (if local)
if [ -d "/etc/letsencrypt/live" ]; then
    echo "[+] Backing up SSL certificates..."
    mkdir -p "$BACKUP_PATH/ssl"
    cp -rL /etc/letsencrypt/live/* "$BACKUP_PATH/ssl/" 2>/dev/null || true
fi

# Create manifest
echo "[+] Creating backup manifest..."
cat > "$BACKUP_PATH/MANIFEST.txt" << EOF
Email System Backup Manifest
============================
Created: $(date)
Hostname: $(hostname)
Domain: xorianindustries.com

Contents:
- postfix/     : Postfix MTA configuration
- dovecot/     : Dovecot IMAP configuration  
- apache2/     : Apache web server configuration
- z-push/      : Z-Push ActiveSync configuration
- postfixadmin/: PostfixAdmin config and database
- roundcube/   : Roundcube config and database
- wireguard/   : WireGuard VPN configuration
- scripts/     : Custom maintenance scripts
- cron/        : Cron job configurations
- ssl/         : SSL certificates (if present)

To restore, run: ./restore-system.sh
EOF

# Create restore script
cat > "$BACKUP_PATH/restore-system.sh" << 'RESTORE'
#!/bin/bash
#===============================================================================
# Email System Restore Script
# Restores all configurations from backup
#===============================================================================

echo "=========================================="
echo "  Email System Restore"
echo "=========================================="
echo ""
echo "WARNING: This will overwrite existing configurations!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[1/8] Restoring Postfix..."
cp -r "$SCRIPT_DIR/postfix/"* /etc/postfix/

echo "[2/8] Restoring Dovecot..."
cp -r "$SCRIPT_DIR/dovecot/"* /etc/dovecot/

echo "[3/8] Restoring Apache..."
cp "$SCRIPT_DIR/apache2/"*.conf /etc/apache2/sites-available/
cp "$SCRIPT_DIR/apache2/ports.conf" /etc/apache2/

echo "[4/8] Restoring Z-Push..."
cp -r "$SCRIPT_DIR/z-push/"* /etc/z-push/

echo "[5/8] Restoring PostfixAdmin..."
cp "$SCRIPT_DIR/postfixadmin/config.local.php" /etc/postfixadmin/
cp "$SCRIPT_DIR/postfixadmin/postfixadmin.db" /var/lib/postfixadmin/
chown www-data:www-data /var/lib/postfixadmin/postfixadmin.db
chmod 664 /var/lib/postfixadmin/postfixadmin.db

echo "[6/8] Restoring Roundcube..."
if [ -f "$SCRIPT_DIR/roundcube/config.inc.php" ]; then
    cp "$SCRIPT_DIR/roundcube/config.inc.php" /var/www/html/roundcube/config/ 2>/dev/null || \
    cp "$SCRIPT_DIR/roundcube/config.inc.php" /etc/roundcube/
fi
if [ -f "$SCRIPT_DIR/roundcube/roundcube.db" ]; then
    cp "$SCRIPT_DIR/roundcube/roundcube.db" /var/lib/roundcube/
    chown www-data:www-data /var/lib/roundcube/roundcube.db
fi

echo "[7/8] Restoring WireGuard..."
cp "$SCRIPT_DIR/wireguard/wg0.conf" /etc/wireguard/
chmod 600 /etc/wireguard/wg0.conf

echo "[8/8] Restoring scripts and cron jobs..."
cp "$SCRIPT_DIR/scripts/"*.sh /usr/local/bin/ 2>/dev/null || true
chmod +x /usr/local/bin/*.sh
cp "$SCRIPT_DIR/cron/"* /etc/cron.d/ 2>/dev/null || true

echo ""
echo "[+] Restarting services..."
systemctl restart postfix dovecot apache2 php7.4-fpm wg-quick@wg0

echo ""
echo "=========================================="
echo "  Restore Complete!"
echo "=========================================="
RESTORE

chmod +x "$BACKUP_PATH/restore-system.sh"

# Create compressed archive
echo "[+] Creating compressed archive..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"

# Calculate size
SIZE=$(du -sh "$BACKUP_NAME.tar.gz" | cut -f1)

# Cleanup uncompressed directory
rm -rf "$BACKUP_PATH"

echo ""
echo "=========================================="
echo "  Backup Complete!"
echo "=========================================="
echo ""
echo "  File: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "  Size: $SIZE"
echo ""
echo "  To restore:"
echo "    1. Extract: tar -xzf $BACKUP_NAME.tar.gz"
echo "    2. Run: cd $BACKUP_NAME && sudo ./restore-system.sh"
echo ""

# Copy to user-accessible location
USER_BACKUP="/home/ns1/backups"
mkdir -p "$USER_BACKUP"
cp "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$USER_BACKUP/"
chown ns1:ns1 "$USER_BACKUP/$BACKUP_NAME.tar.gz"

echo "  Also copied to: $USER_BACKUP/$BACKUP_NAME.tar.gz"
echo ""
