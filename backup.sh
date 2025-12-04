#!/bin/bash

# Database Backup Script for n8n PostgreSQL
# Creates both compressed (.dump) and SQL (.sql) backups

set -e  # Exit on error

# Configuration
BACKUP_DIR="./backups"
CONTAINER_NAME="n8n_postgres"
DB_USER="n8n_user"
DB_NAME="n8n"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== n8n Database Backup Script ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if PostgreSQL container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: PostgreSQL container '$CONTAINER_NAME' is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1/4: Creating compressed backup (.dump)...${NC}"
# Create compressed backup
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" -F c -f /tmp/backup.dump
docker cp "$CONTAINER_NAME:/tmp/backup.dump" "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump"
docker exec "$CONTAINER_NAME" rm /tmp/backup.dump

echo -e "${GREEN}✓ Compressed backup created: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump${NC}"

echo -e "${YELLOW}Step 2/4: Creating SQL backup (.sql)...${NC}"
# Create SQL backup
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql"

echo -e "${GREEN}✓ SQL backup created: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql${NC}"

echo -e "${YELLOW}Step 3/4: Setting secure permissions...${NC}"
# Set secure permissions (read/write for owner only)
chmod 600 "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump"
chmod 600 "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql"

echo -e "${GREEN}✓ Permissions set to 600 (owner read/write only)${NC}"

echo -e "${YELLOW}Step 4/4: Verifying backups...${NC}"
# Verify backup files
DUMP_SIZE=$(stat -f%z "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" 2>/dev/null || stat -c%s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump")
SQL_SIZE=$(stat -f%z "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" 2>/dev/null || stat -c%s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql")

if [ "$DUMP_SIZE" -gt 0 ] && [ "$SQL_SIZE" -gt 0 ]; then
    echo -e "${GREEN}✓ Backup verification successful${NC}"
    echo ""
    echo -e "${GREEN}=== Backup Summary ===${NC}"
    echo "Compressed backup: $(du -h "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" | cut -f1)"
    echo "SQL backup: $(du -h "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" | cut -f1)"
    echo ""
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo "Files are located in: $BACKUP_DIR/"
else
    echo -e "${RED}Error: Backup files are empty or invalid${NC}"
    exit 1
fi

# Optional: Clean up old backups (keep last 10)
echo ""
echo -e "${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"
ls -t "$BACKUP_DIR"/n8n_backup_*.dump 2>/dev/null | tail -n +11 | xargs -r rm
ls -t "$BACKUP_DIR"/n8n_backup_*.sql 2>/dev/null | tail -n +11 | xargs -r rm
echo -e "${GREEN}✓ Old backups cleaned${NC}"

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Copy backup to VPS: scp $BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump user@your-vps:/path/"
echo "2. Or upload to cloud storage for safekeeping"
echo "3. Test restore on VPS before going live"
