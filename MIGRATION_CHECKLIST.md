# VPS Migration Checklist

Use this checklist to ensure a smooth migration of your n8n stock project to VPS.

## Pre-Migration (Local Machine)

### 1. Preparation
- [ ] Stop all running n8n workflows
- [ ] Document current system state
  - [ ] Note Docker container status: `docker ps`
  - [ ] Check Docker volumes: `docker volume ls`
  - [ ] Verify current data size: `docker exec n8n_postgres psql -U n8n_user -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"`
- [ ] Create `.env` backup copy in secure location
- [ ] Document all custom configurations

### 2. Database Backup
- [ ] Run backup script: `./backup.sh`
- [ ] Verify backup files exist:
  ```bash
  ls -lh backups/
  ```
- [ ] Check backup file size (should be > 0 bytes)
- [ ] Optional: Test backup restore locally
  ```bash
  # Create test database
  docker exec n8n_postgres psql -U n8n_user -c "CREATE DATABASE test_restore;"
  # Restore
  docker exec -i n8n_postgres pg_restore -U n8n_user -d test_restore < backups/latest.dump
  # Drop test database
  docker exec n8n_postgres psql -U n8n_user -c "DROP DATABASE test_restore;"
  ```
- [ ] Copy backup to external storage (USB drive, cloud storage)

### 3. Export Configurations
- [ ] Export pgAdmin settings (if customized)
- [ ] Save Cloudflare Tunnel token from `.env`
- [ ] Document any custom workflow credentials
- [ ] List all active API integrations:
  - [ ] EODHD API
  - [ ] OpenAI API
  - [ ] Others: _______________

### 4. Documentation
- [ ] List all custom modifications to docker-compose.yml
- [ ] Note any custom environment variables
- [ ] Document external dependencies
- [ ] Take screenshots of:
  - [ ] n8n workflow list
  - [ ] Active executions
  - [ ] Credential list (names only, not values)

---

## VPS Preparation

### 1. VPS Provisioning
- [ ] Choose VPS provider: _______________
- [ ] Select plan (min 4GB RAM, 2 CPU, 50GB storage)
- [ ] Operating system: Ubuntu 22.04 LTS
- [ ] Note VPS IP address: _______________
- [ ] Configure DNS:
  - [ ] Point domain to VPS IP
  - [ ] Wait for DNS propagation (can take up to 48 hours)

### 2. Initial VPS Access
- [ ] SSH into VPS: `ssh root@YOUR_VPS_IP`
- [ ] Change root password (if needed)
- [ ] Update system:
  ```bash
  apt update && apt upgrade -y
  ```
- [ ] Verify timezone:
  ```bash
  timedatectl
  ```

### 3. Run VPS Setup Script
- [ ] Transfer setup script to VPS:
  ```bash
  scp vps-setup.sh root@YOUR_VPS_IP:/root/
  ```
- [ ] Run setup script:
  ```bash
  ssh root@YOUR_VPS_IP
  chmod +x vps-setup.sh
  ./vps-setup.sh
  ```
- [ ] Verify setup completed successfully
- [ ] Note non-root username: _______________

### 4. Security Configuration
- [ ] Set up SSH key authentication
  ```bash
  ssh-copy-id username@YOUR_VPS_IP
  ```
- [ ] Test SSH key login
- [ ] Disable password authentication (optional)
- [ ] Configure firewall rules
  - [ ] Port 22 (SSH) - ✓
  - [ ] Port 80 (HTTP) - ✓
  - [ ] Port 443 (HTTPS) - ✓
  - [ ] Port 5678 (n8n) - Optional
  - [ ] Port 8080 (pgAdmin) - Optional
- [ ] Verify firewall status: `sudo ufw status`

---

## File Transfer

### 1. Transfer Project Files
- [ ] Clone repository on VPS:
  ```bash
  git clone https://github.com/ahmadhanimustafa/stock_project.git
  cd stock_project
  git checkout claude/vps-migration-setup-01QnPMnJW83ejXWk8yh4Ybda
  ```

### 2. Transfer Database Backup
Choose one method:
- [ ] Method A: SCP
  ```bash
  scp backups/n8n_backup_*.dump user@VPS_IP:/home/user/stock_project/backups/
  ```
- [ ] Method B: rsync
  ```bash
  rsync -avz --progress backups/ user@VPS_IP:/home/user/stock_project/backups/
  ```
- [ ] Method C: Cloud upload + download
  - [ ] Upload to cloud: _______________
  - [ ] Download on VPS: _______________

### 3. Transfer Configuration Files
- [ ] Transfer .env file:
  ```bash
  scp .env user@VPS_IP:/home/user/stock_project/.env
  ```
- [ ] Verify .env transferred correctly:
  ```bash
  ssh user@VPS_IP "cat ~/stock_project/.env | head -5"
  ```

### 4. Update Configuration for VPS
- [ ] Edit .env on VPS:
  ```bash
  nano .env
  ```
- [ ] Update N8N_HOST to VPS domain/IP
- [ ] Update CLOUDFLARE_TUNNEL_TOKEN (if creating new tunnel)
- [ ] Verify all other settings are correct
- [ ] Save and exit

---

## Deployment on VPS

### 1. Pre-Deployment Checks
- [ ] Verify Docker is installed: `docker --version`
- [ ] Verify Docker Compose is installed: `docker compose version`
- [ ] Check available disk space: `df -h`
- [ ] Verify .env file exists: `ls -la .env`
- [ ] Verify backup file exists: `ls -la backups/`

### 2. Deploy Services
- [ ] Make deployment script executable:
  ```bash
  chmod +x deploy-vps.sh
  ```
- [ ] Run deployment:
  ```bash
  ./deploy-vps.sh backups/n8n_backup_YYYYMMDD_HHMMSS.dump
  ```
- [ ] Monitor deployment output for errors
- [ ] Wait for all services to start

### 3. Verify Deployment
- [ ] Check all containers running:
  ```bash
  docker compose ps
  ```
- [ ] Verify PostgreSQL is healthy:
  ```bash
  docker exec n8n_postgres pg_isready -U n8n_user
  ```
- [ ] Check n8n logs:
  ```bash
  docker logs n8n --tail=50
  ```
- [ ] Verify no critical errors in logs

---

## Post-Deployment Verification

### 1. Database Verification
- [ ] Connect to database:
  ```bash
  docker exec -it n8n_postgres psql -U n8n_user -d n8n
  ```
- [ ] Check table count:
  ```sql
  \dt
  ```
- [ ] Verify data in key tables:
  ```sql
  SELECT COUNT(*) FROM dim_symbol;
  SELECT COUNT(*) FROM fact_daily_ohlcv;
  SELECT MAX(date) FROM fact_daily_ohlcv;
  \q
  ```
- [ ] Compare counts with local database

### 2. n8n Web Interface
- [ ] Access n8n via domain: `https://n8n.datamentor.work`
- [ ] Or via IP: `http://VPS_IP:5678`
- [ ] Login with credentials from .env
- [ ] Verify login successful

### 3. Workflows Verification
- [ ] Check all workflows are visible
- [ ] Count workflows (should match local):
  - Local count: _____
  - VPS count: _____
- [ ] Verify workflow status (active/inactive)
- [ ] Check recent execution history

### 4. Credentials Verification
- [ ] Go to Credentials page in n8n
- [ ] Verify all credentials exist (count):
  - Local count: _____
  - VPS count: _____
- [ ] Re-enter sensitive credentials if needed:
  - [ ] EODHD API Token
  - [ ] OpenAI API Key
  - [ ] Other API keys: _______________

### 5. Test Workflow Execution
- [ ] Select a simple workflow (e.g., wf_01_sync_symbols)
- [ ] Run manual execution
- [ ] Verify execution completes successfully
- [ ] Check execution log for errors
- [ ] Verify data written to database

### 6. Cloudflare Tunnel (if applicable)
- [ ] Check cloudflared container status:
  ```bash
  docker logs cloudflared
  ```
- [ ] Verify domain accessible: `https://n8n.datamentor.work`
- [ ] Test from external network (mobile phone)
- [ ] Verify SSL certificate (should show secure lock)

### 7. pgAdmin Access
- [ ] Access pgAdmin: `http://VPS_IP:8080`
- [ ] Login with credentials from .env
- [ ] Connect to PostgreSQL server
- [ ] Browse database tables
- [ ] Run test query

---

## Monitoring & Maintenance Setup

### 1. Automated Backups
- [ ] Make backup script executable:
  ```bash
  chmod +x backup.sh
  ```
- [ ] Test backup script:
  ```bash
  ./backup.sh
  ```
- [ ] Set up cron job:
  ```bash
  crontab -e
  # Add: 0 2 * * * cd /home/user/stock_project && ./backup.sh >> /home/user/backup.log 2>&1
  ```
- [ ] Verify cron job added:
  ```bash
  crontab -l
  ```

### 2. Log Rotation
- [ ] Set up log rotation for Docker logs
- [ ] Configure retention policy (e.g., keep 7 days)

### 3. Monitoring (Optional)
- [ ] Install Portainer (optional):
  ```bash
  docker volume create portainer_data
  docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
  ```
- [ ] Or install Uptime Kuma for uptime monitoring
- [ ] Or set up custom monitoring solution

### 4. Alerts (Optional)
- [ ] Set up email alerts for:
  - [ ] Docker container failures
  - [ ] Disk space warnings (>80%)
  - [ ] Workflow execution failures
- [ ] Configure Telegram/Slack notifications (if desired)

---

## Final Validation (24-48 Hours)

### Day 1 Checks
- [ ] All workflows executed successfully
- [ ] No critical errors in logs
- [ ] Scheduled workflows running on time
- [ ] API integrations working
- [ ] Database backups running automatically
- [ ] Disk space sufficient
- [ ] CPU/RAM usage normal

### Day 2 Checks
- [ ] Verify 24-hour stability
- [ ] Check workflow execution count
- [ ] Review backup files generated
- [ ] Monitor resource usage trends
- [ ] Test disaster recovery (optional):
  - [ ] Stop services
  - [ ] Restore from backup
  - [ ] Verify restoration successful
  - [ ] Restart normal operations

### Week 1 Validation
- [ ] One week of stable operation
- [ ] All scheduled workflows running
- [ ] No data loss or corruption
- [ ] Performance acceptable
- [ ] Backup rotation working
- [ ] Monitoring alerts working (if configured)

---

## Decommission Local Environment

**Only after 1 week of stable VPS operation:**

- [ ] Export final backup from local:
  ```bash
  ./backup.sh
  ```
- [ ] Archive local backups to external storage
- [ ] Stop local Docker containers:
  ```bash
  docker compose down
  ```
- [ ] Optional: Remove Docker volumes (careful!):
  ```bash
  docker volume rm pg_data n8n_data
  ```
- [ ] Keep project files for reference
- [ ] Update documentation with VPS details

---

## Rollback Plan (If Issues Occur)

### Scenario 1: VPS Deployment Fails
- [ ] Keep local environment running
- [ ] Document error messages
- [ ] Troubleshoot on VPS without affecting local
- [ ] Retry deployment after fixing issues

### Scenario 2: Data Migration Issues
- [ ] Restore backup on VPS again
- [ ] Verify backup file integrity
- [ ] Check PostgreSQL logs for errors
- [ ] Contact support if needed

### Scenario 3: Complete Rollback
- [ ] Stop VPS services
- [ ] Restart local environment
- [ ] Continue using local until issues resolved
- [ ] Schedule retry migration

---

## Success Criteria

Migration is successful when:
- ✅ All services running on VPS
- ✅ Database fully restored and verified
- ✅ All workflows visible and executable
- ✅ API integrations working
- ✅ Scheduled workflows running on time
- ✅ No critical errors in logs
- ✅ Performance acceptable
- ✅ Automated backups working
- ✅ Accessible via domain (if using Cloudflare)
- ✅ 1 week of stable operation

---

## Migration Timeline Estimate

- **VPS Setup**: 30-60 minutes
- **File Transfer**: 15-30 minutes (depends on backup size and internet speed)
- **Deployment**: 20-30 minutes
- **Verification**: 30-60 minutes
- **Monitoring Setup**: 15-30 minutes
- **Total**: 2-4 hours

---

## Notes & Issues

Document any issues or deviations from plan here:

```
Date: _______________
Issue: _______________
Resolution: _______________

Date: _______________
Issue: _______________
Resolution: _______________
```

---

## Sign-Off

- [ ] Migration completed by: _______________
- [ ] Date completed: _______________
- [ ] VPS IP: _______________
- [ ] Domain: _______________
- [ ] All checks passed: _______________
- [ ] Documentation updated: _______________

---

**Note**: Keep this checklist for reference and future migrations.
