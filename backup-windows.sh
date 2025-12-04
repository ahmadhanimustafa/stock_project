#!/bin/bash

# Database Backup Script for n8n PostgreSQL (Windows Compatible)
# Works with Docker Desktop on Windows

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

echo -e "${GREEN}=== n8n Database Backup Script (Windows) ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if PostgreSQL container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: PostgreSQL container '$CONTAINER_NAME' is not running${NC}"
    echo "Start it with: docker compose up -d postgres"
    exit 1
fi

echo -e "${YELLOW}Step 1/3: Creating compressed backup (.dump)...${NC}"
# Create compressed backup directly to host (Windows-compatible)
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" -F c | cat > "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump"

echo -e "${GREEN}✓ Compressed backup created: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump${NC}"

echo -e "${YELLOW}Step 2/3: Creating SQL backup (.sql)...${NC}"
# Create SQL backup directly to host
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql"

echo -e "${GREEN}✓ SQL backup created: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql${NC}"

echo -e "${YELLOW}Step 3/3: Verifying backups...${NC}"
# Verify backup files
if [ -f "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" ] && [ -s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" ]; then
    DUMP_SIZE=$(stat -c%s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" 2>/dev/null || stat -f%z "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump" 2>/dev/null || wc -c < "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump")
    echo -e "${GREEN}✓ Dump backup size: $(numfmt --to=iec-i --suffix=B $DUMP_SIZE 2>/dev/null || echo "$DUMP_SIZE bytes")${NC}"
else
    echo -e "${RED}Error: Dump backup file is empty or missing${NC}"
    exit 1
fi

if [ -f "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" ] && [ -s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" ]; then
    SQL_SIZE=$(stat -c%s "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" 2>/dev/null || stat -f%z "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql" 2>/dev/null || wc -c < "$BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql")
    echo -e "${GREEN}✓ SQL backup size: $(numfmt --to=iec-i --suffix=B $SQL_SIZE 2>/dev/null || echo "$SQL_SIZE bytes")${NC}"
else
    echo -e "${RED}Error: SQL backup file is empty or missing${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Backup Summary ===${NC}"
echo "Compressed backup: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump"
echo "SQL backup: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.sql"
echo ""
echo -e "${GREEN}Backup completed successfully!${NC}"

# Optional: Clean up old backups (keep last 10)
echo ""
echo -e "${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"

# Count existing backups
DUMP_COUNT=$(ls -1 "$BACKUP_DIR"/n8n_backup_*.dump 2>/dev/null | wc -l)
SQL_COUNT=$(ls -1 "$BACKUP_DIR"/n8n_backup_*.sql 2>/dev/null | wc -l)

if [ "$DUMP_COUNT" -gt 10 ]; then
    ls -1t "$BACKUP_DIR"/n8n_backup_*.dump | tail -n +11 | xargs rm -f
    echo -e "${GREEN}✓ Cleaned up old .dump backups${NC}"
fi

if [ "$SQL_COUNT" -gt 10 ]; then
    ls -1t "$BACKUP_DIR"/n8n_backup_*.sql | tail -n +11 | xargs rm -f
    echo -e "${GREEN}✓ Cleaned up old .sql backups${NC}"
fi

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Verify backup files:"
echo "   ls -lh $BACKUP_DIR/"
echo ""
echo "2. Copy backup to VPS:"
echo "   scp $BACKUP_DIR/n8n_backup_${TIMESTAMP}.dump user@your-vps:/path/"
echo ""
echo "3. Or upload to cloud storage for safekeeping"
echo ""
echo "4. Test restore on VPS before going live"
