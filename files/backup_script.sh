#!/bin/bash
BACKUP_DIR="/mnt/backup_volume"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Backup NGINX configs
tar -czf "$BACKUP_DIR/$DATE/nginx_configs.tar.gz" /etc/nginx/

# Backup NFS exports
cp /etc/exports "$BACKUP_DIR/$DATE/exports.backup"

# Backup Docker containers data
docker ps -a > "$BACKUP_DIR/$DATE/containers_list.txt"

# Backup Grafana dashboards (if container is running)
if docker ps | grep -q grafana; then
    docker exec grafana ls -la /var/lib/grafana/dashboards > "$BACKUP_DIR/$DATE/grafana_dashboards.txt" 2>/dev/null
fi

# Remove old backups
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} +

echo "Backup completed: $DATE"