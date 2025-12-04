# Database Backup Guide

This guide explains how to backup your PostgreSQL database before VPS migration.

## Quick Backup (Recommended)

### 1. Backup Using Docker Exec (Current Setup)

```bash
# Create backup directory
mkdir -p backups

# Backup entire database with timestamp
docker exec n8n_postgres pg_dump -U n8n_user -d n8n -F c -f /tmp/backup.dump
docker cp n8n_postgres:/tmp/backup.dump ./backups/n8n_backup_$(date +%Y%m%d_%H%M%S).dump

# Alternative: SQL format (human-readable)
docker exec n8n_postgres pg_dump -U n8n_user -d n8n > ./backups/n8n_backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Backup All Databases (Including n8n system tables)

```bash
# Backup all databases (including n8n workflow definitions)
docker exec n8n_postgres pg_dumpall -U n8n_user > ./backups/full_backup_$(date +%Y%m%d_%H%M%S).sql
```

## Automated Backup Script

Use the provided `backup.sh` script:

```bash
# Make script executable
chmod +x backup.sh

# Run backup
./backup.sh
```

This will create:
- `backups/n8n_backup_YYYYMMDD_HHMMSS.dump` (compressed format)
- `backups/n8n_backup_YYYYMMDD_HHMMSS.sql` (SQL format)

## Verify Backup

```bash
# Check backup file size (should be > 0)
ls -lh backups/

# Test restore to a temporary database (optional)
docker exec -i n8n_postgres psql -U n8n_user -c "CREATE DATABASE test_restore;"
docker exec -i n8n_postgres pg_restore -U n8n_user -d test_restore < backups/n8n_backup_YYYYMMDD_HHMMSS.dump
docker exec -i n8n_postgres psql -U n8n_user -c "DROP DATABASE test_restore;"
```

## What Gets Backed Up

Your backup includes:
- ✅ All workflow definitions (n8n internal tables)
- ✅ Stock symbols (`dim_symbol`)
- ✅ Fundamentals data (`dim_fundamentals`)
- ✅ Historical OHLCV data (`fact_daily_ohlcv`)
- ✅ Technical indicators (`fact_tech_indicators`)
- ✅ Risk/reward metrics
- ✅ Trading logs
- ✅ Configuration tables
- ✅ Views and indexes

## Backup Before Migration Checklist

- [ ] Stop all running n8n workflows
- [ ] Wait for any active executions to complete
- [ ] Run full backup using `backup.sh`
- [ ] Verify backup file exists and size > 0
- [ ] Copy backup files to secure location (external drive, cloud storage)
- [ ] Test backup restore (optional but recommended)

## Restore Database (For VPS Migration)

```bash
# On VPS: Restore from dump file
docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n -c < n8n_backup_YYYYMMDD_HHMMSS.dump

# On VPS: Restore from SQL file
docker exec -i n8n_postgres psql -U n8n_user -d n8n < n8n_backup_YYYYMMDD_HHMMSS.sql
```

## Security Notes

- Backup files contain sensitive data (API keys, passwords in n8n workflows)
- **Never commit backup files to Git** (already in .gitignore)
- Store backups in encrypted storage
- Limit backup file access permissions: `chmod 600 backups/*.dump`

## Troubleshooting

**Problem**: `pg_dump: error: connection to server failed`
- **Solution**: Ensure PostgreSQL container is running: `docker ps | grep postgres`

**Problem**: Backup file is 0 bytes
- **Solution**: Check Docker container logs: `docker logs n8n_postgres`

**Problem**: Permission denied
- **Solution**: Run with proper permissions or use `sudo` if needed
