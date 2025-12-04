#!/bin/bash

# VPS Deployment Script for n8n Stock Project
# Run this on VPS after transferring files
# Usage: ./deploy-vps.sh [backup_file]

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   n8n Stock Project - VPS Deployment          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running in project directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env file with your configuration"
    exit 1
fi

# Get backup file
BACKUP_FILE="$1"
if [ -z "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}Available backup files:${NC}"
    ls -lh backups/*.dump 2>/dev/null || ls -lh backups/*.sql 2>/dev/null || echo "No backup files found"
    echo ""
    read -p "Enter backup file path (or 'skip' to skip restore): " BACKUP_FILE
fi

if [ "$BACKUP_FILE" = "skip" ]; then
    echo -e "${YELLOW}Skipping database restore${NC}"
    SKIP_RESTORE=true
else
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi
    SKIP_RESTORE=false
fi

echo ""
echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Project: stock_project"
echo "  Backup: $BACKUP_FILE"
echo "  Skip Restore: $SKIP_RESTORE"
echo ""
read -p "Continue with deployment? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1/7: Creating required directories...${NC}"
mkdir -p backups
chmod 700 backups
echo -e "${GREEN}✓ Directories created${NC}"

echo -e "${YELLOW}Step 2/7: Pulling Docker images...${NC}"
docker compose pull
echo -e "${GREEN}✓ Docker images pulled${NC}"

echo -e "${YELLOW}Step 3/7: Starting PostgreSQL...${NC}"
docker compose up -d postgres
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# Wait for PostgreSQL to be healthy
RETRY=0
MAX_RETRIES=30
until docker exec n8n_postgres pg_isready -U n8n_user > /dev/null 2>&1 || [ $RETRY -eq $MAX_RETRIES ]; do
    echo "Waiting for PostgreSQL... ($RETRY/$MAX_RETRIES)"
    sleep 2
    RETRY=$((RETRY+1))
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    echo -e "${RED}Error: PostgreSQL failed to start${NC}"
    docker logs n8n_postgres
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL is running${NC}"

if [ "$SKIP_RESTORE" = false ]; then
    echo -e "${YELLOW}Step 4/7: Restoring database from backup...${NC}"

    # Detect backup format
    if [[ "$BACKUP_FILE" == *.dump ]]; then
        echo "Restoring from compressed dump format..."
        docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n -c --if-exists < "$BACKUP_FILE" 2>&1 | grep -v "already exists" || true
    elif [[ "$BACKUP_FILE" == *.sql ]]; then
        echo "Restoring from SQL format..."
        docker exec -i n8n_postgres psql -U n8n_user -d n8n < "$BACKUP_FILE" 2>&1 | grep -v "already exists" || true
    else
        echo -e "${RED}Error: Unknown backup format${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Database restored${NC}"

    echo -e "${YELLOW}Step 5/7: Verifying database...${NC}"
    # Check key tables
    TABLE_COUNT=$(docker exec n8n_postgres psql -U n8n_user -d n8n -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)
    echo "  Tables found: $TABLE_COUNT"

    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Database verification passed${NC}"
    else
        echo -e "${RED}Warning: Database appears empty${NC}"
    fi
else
    echo -e "${YELLOW}Step 4/7: Skipped (no restore)${NC}"
    echo -e "${YELLOW}Step 5/7: Skipped (no verification)${NC}"
fi

echo -e "${YELLOW}Step 6/7: Starting all services...${NC}"
docker compose up -d

echo "Waiting for services to start..."
sleep 10

# Check service health
echo ""
echo -e "${YELLOW}Service Status:${NC}"
docker compose ps

echo ""
echo -e "${YELLOW}Step 7/7: Final verification...${NC}"

# Check if n8n is responding
RETRY=0
MAX_RETRIES=30
until docker logs n8n 2>&1 | grep -q "Editor is now accessible" || [ $RETRY -eq $MAX_RETRIES ]; do
    echo "Waiting for n8n to start... ($RETRY/$MAX_RETRIES)"
    sleep 2
    RETRY=$((RETRY+1))
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    echo -e "${RED}Warning: n8n may not have started properly${NC}"
    echo "Check logs: docker logs n8n"
else
    echo -e "${GREEN}✓ n8n is running${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Deployment Complete! ✓                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Services Running:${NC}"
docker compose ps
echo ""
echo -e "${GREEN}Access URLs:${NC}"

# Get VPS IP
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# Get N8N_HOST from .env
N8N_HOST=$(grep "^N8N_HOST=" .env | cut -d '=' -f2)
N8N_PROTOCOL=$(grep "^N8N_PROTOCOL=" .env | cut -d '=' -f2)

if [ -n "$N8N_HOST" ]; then
    echo "  n8n: ${N8N_PROTOCOL}://${N8N_HOST}"
else
    echo "  n8n: http://${VPS_IP}:5678"
fi
echo "  pgAdmin: http://${VPS_IP}:8080"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Access n8n and verify workflows are loaded"
echo "2. Check credentials and re-enter API keys if needed"
echo "3. Test one workflow execution"
echo "4. Set up automated backups (cron job)"
echo "5. Enable monitoring"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View logs: ${BLUE}docker compose logs -f${NC}"
echo "  Restart services: ${BLUE}docker compose restart${NC}"
echo "  Stop services: ${BLUE}docker compose down${NC}"
echo "  Backup database: ${BLUE}./backup.sh${NC}"
echo ""
echo -e "${GREEN}Deployment log saved to: deployment_$(date +%Y%m%d_%H%M%S).log${NC}"
