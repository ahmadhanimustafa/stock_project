# VPS Migration Guide - Stock Project (n8n)

Complete guide to migrate your n8n stock trading automation system to a VPS.

## Table of Contents
1. [VPS Requirements](#vps-requirements)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Step-by-Step Migration](#step-by-step-migration)
4. [Post-Migration Verification](#post-migration-verification)
5. [Troubleshooting](#troubleshooting)

---

## VPS Requirements

### Minimum Specifications
- **CPU**: 2 cores (4+ recommended for heavy workflows)
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 50GB SSD minimum (100GB+ recommended for historical data)
- **OS**: Ubuntu 22.04 LTS or Debian 12 (recommended)
- **Network**: Static IP with open ports 80, 443, 5678

### Required Software on VPS
- Docker Engine (v24+)
- Docker Compose (v2.0+)
- Git
- UFW or iptables (firewall)
- Optional: Nginx (if not using Cloudflare Tunnel)

### VPS Provider Recommendations
- **DigitalOcean**: Droplet ($24/month for 4GB RAM)
- **Linode/Akamai**: Shared CPU ($24/month for 4GB RAM)
- **Vultr**: Cloud Compute ($18/month for 4GB RAM)
- **AWS Lightsail**: $20/month for 4GB RAM
- **Hetzner**: Best value (~€9/month for 4GB RAM, EU only)

---

## Pre-Migration Checklist

### On Local Machine

- [ ] **Stop all n8n workflows** (prevent data inconsistency)
- [ ] **Create database backup** using `./backup.sh`
- [ ] **Verify backup files** exist in `backups/` directory
- [ ] **Document current .env settings** (copy to secure location)
- [ ] **Export Cloudflare Tunnel config** (if using)
- [ ] **Test backup integrity** (optional but recommended)
- [ ] **Note current Docker volumes**:
  ```bash
  docker volume ls | grep n8n
  ```

### On VPS (Initial Setup)

- [ ] **Provision VPS** with Ubuntu 22.04 LTS
- [ ] **Set up SSH key authentication** (disable password auth)
- [ ] **Update system packages**:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- [ ] **Install Docker**
- [ ] **Install Docker Compose**
- [ ] **Configure firewall**
- [ ] **Set up domain DNS** (point to VPS IP)
- [ ] **Configure timezone** (Asia/Jakarta)

---

## Step-by-Step Migration

### Phase 1: VPS Initial Setup (30-60 minutes)

#### 1.1 Connect to VPS

```bash
# From local machine
ssh root@YOUR_VPS_IP

# Or if using key-based auth
ssh -i ~/.ssh/your_key.pem user@YOUR_VPS_IP
```

#### 1.2 Create Non-Root User (Security Best Practice)

```bash
# Create user
adduser n8nuser
usermod -aG sudo n8nuser
usermod -aG docker n8nuser

# Switch to new user
su - n8nuser
```

#### 1.3 Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
docker compose version
```

#### 1.4 Install Required Tools

```bash
# Install Git, curl, and utilities
sudo apt install -y git curl wget nano htop net-tools ufw

# Set timezone to Asia/Jakarta
sudo timedatectl set-timezone Asia/Jakarta

# Verify
timedatectl
```

#### 1.5 Configure Firewall

```bash
# Allow SSH (important - do this first!)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS (if not using Cloudflare Tunnel)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow n8n port (optional, for direct access)
sudo ufw allow 5678/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

---

### Phase 2: Transfer Files to VPS (15-30 minutes)

#### 2.1 Clone Repository to VPS

```bash
# On VPS
cd ~
git clone https://github.com/ahmadhanimustafa/stock_project.git
cd stock_project

# Checkout the migration branch
git checkout claude/vps-migration-setup-01QnPMnJW83ejXWk8yh4Ybda
```

#### 2.2 Transfer Database Backup

**Option A: Using SCP (from local machine)**
```bash
# From local machine
scp backups/n8n_backup_*.dump user@YOUR_VPS_IP:/home/n8nuser/stock_project/backups/
```

**Option B: Using rsync (recommended for large files)**
```bash
# From local machine
rsync -avz --progress backups/ user@YOUR_VPS_IP:/home/n8nuser/stock_project/backups/
```

**Option C: Upload to cloud and download on VPS**
```bash
# Upload to Dropbox/Google Drive/S3, then on VPS:
wget "YOUR_BACKUP_URL" -O backups/n8n_backup.dump
```

#### 2.3 Transfer .env File

```bash
# From local machine
scp .env user@YOUR_VPS_IP:/home/n8nuser/stock_project/.env

# OR manually create on VPS
nano .env
# Paste your .env contents
```

**IMPORTANT**: Update `.env` on VPS with new settings:
```env
# Update domain if needed
N8N_HOST=your-vps-domain.com  # or VPS IP

# Update Cloudflare Tunnel token if needed
CLOUDFLARE_TUNNEL_TOKEN=your_new_token

# Keep other settings the same
```

---

### Phase 3: Deploy Services on VPS (20-30 minutes)

#### 3.1 Review docker-compose.yml

```bash
# On VPS
cd ~/stock_project
cat docker-compose.yml
```

Ensure all volume paths and settings are correct.

#### 3.2 Create Required Directories

```bash
# Create backup directory
mkdir -p backups

# Set permissions
chmod 700 backups
```

#### 3.3 Start PostgreSQL First

```bash
# Start only PostgreSQL
docker compose up -d postgres

# Wait for PostgreSQL to be ready (30 seconds)
sleep 30

# Check status
docker ps | grep postgres
docker logs n8n_postgres
```

#### 3.4 Restore Database Backup

```bash
# Check if database exists
docker exec n8n_postgres psql -U n8n_user -l

# Restore from backup (.dump format - recommended)
docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n -c --if-exists < backups/n8n_backup_YYYYMMDD_HHMMSS.dump

# OR restore from SQL format
docker exec -i n8n_postgres psql -U n8n_user -d n8n < backups/n8n_backup_YYYYMMDD_HHMMSS.sql
```

**Note**: You may see some errors like "relation already exists" - this is normal and can be ignored if using `-c` flag.

#### 3.5 Verify Database Restoration

```bash
# Connect to database
docker exec -it n8n_postgres psql -U n8n_user -d n8n

# Check tables exist
\dt

# Check row counts
SELECT COUNT(*) FROM dim_symbol;
SELECT COUNT(*) FROM fact_daily_ohlcv;

# Exit psql
\q
```

#### 3.6 Start All Services

```bash
# Start all containers
docker compose up -d

# Verify all services are running
docker compose ps

# Check logs
docker compose logs -f n8n
```

---

### Phase 4: Configure Cloudflare Tunnel (15-30 minutes)

#### 4.1 Update Cloudflare Tunnel Configuration

If you're using Cloudflare Tunnel (recommended for security):

**Option A: Keep Existing Tunnel**
- Use the same `CLOUDFLARE_TUNNEL_TOKEN` in your `.env`
- Update DNS in Cloudflare dashboard to point to VPS

**Option B: Create New Tunnel**
```bash
# Install cloudflared on VPS
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create n8n-stock-vps

# Get tunnel ID and update .env
# CLOUDFLARE_TUNNEL_TOKEN=<your_new_token>

# Restart cloudflared container
docker compose restart cloudflared
```

#### 4.2 Update DNS Records

In Cloudflare dashboard:
1. Go to your domain's DNS settings
2. Update CNAME for `n8n.datamentor.work`:
   - Type: CNAME
   - Name: n8n
   - Target: `<tunnel-id>.cfargotunnel.com`
   - Proxy: Yes (orange cloud)

---

### Phase 5: Post-Migration Verification (15 minutes)

#### 5.1 Access n8n Web Interface

```bash
# Via Cloudflare Tunnel
https://n8n.datamentor.work

# Or direct access (if firewall allows)
http://YOUR_VPS_IP:5678
```

Login with credentials from `.env`:
- Username: `admin`
- Password: `another_Str0ngPass!`

#### 5.2 Verify Workflows

- [ ] Check all workflows are imported
- [ ] Verify credentials are intact (may need to re-enter API keys)
- [ ] Test one workflow execution
- [ ] Check workflow execution history

#### 5.3 Verify Database

```bash
# Check pgAdmin access
http://YOUR_VPS_IP:8080

# Verify data in key tables
docker exec -it n8n_postgres psql -U n8n_user -d n8n -c "SELECT COUNT(*) FROM dim_symbol;"
docker exec -it n8n_postgres psql -U n8n_user -d n8n -c "SELECT MAX(date) FROM fact_daily_ohlcv;"
```

#### 5.4 Test API Integrations

- [ ] EODHD API connection (run symbol sync workflow)
- [ ] OpenAI API connection (if used)
- [ ] Database write operations
- [ ] Scheduled workflows (check cron triggers)

---

### Phase 6: Enable Automated Backups on VPS

#### 6.1 Set Up Cron Job for Daily Backups

```bash
# On VPS
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /home/n8nuser/stock_project && ./backup.sh >> /home/n8nuser/backup.log 2>&1
```

#### 6.2 Set Up Backup Retention Policy

Edit `backup.sh` to adjust retention (currently keeps last 10 backups).

#### 6.3 Test Backup Script

```bash
cd ~/stock_project
./backup.sh
ls -lh backups/
```

---

### Phase 7: Security Hardening

#### 7.1 Change Default Passwords

Update `.env` with strong passwords:
```env
N8N_BASIC_AUTH_PASSWORD=<new_strong_password>
POSTGRES_PASSWORD=<new_strong_password>
```

Then restart services:
```bash
docker compose down
docker compose up -d
```

#### 7.2 Enable SSL/TLS (if not using Cloudflare Tunnel)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d n8n.datamentor.work
```

#### 7.3 Limit SSH Access

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Set:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

#### 7.4 Set Up Docker Resource Limits

Edit `docker-compose.yml` to add resource limits:
```yaml
services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
```

---

## Post-Migration Verification Checklist

- [ ] n8n web interface accessible via domain
- [ ] All workflows visible in n8n
- [ ] Database contains all historical data
- [ ] Test workflow executions successful
- [ ] Scheduled workflows running on time
- [ ] API credentials working (EODHD, OpenAI)
- [ ] Database backups automated via cron
- [ ] Firewall configured correctly
- [ ] SSL/TLS enabled (if not using Cloudflare)
- [ ] Monitoring set up (optional: Portainer, Grafana)
- [ ] Docker containers auto-restart on failure
- [ ] Cloudflare Tunnel working (if used)

---

## Troubleshooting

### Problem: Cannot connect to VPS

**Solution**:
```bash
# Check firewall
sudo ufw status

# Ensure SSH port is open
sudo ufw allow 22/tcp

# Check SSH service
sudo systemctl status sshd
```

### Problem: Docker containers not starting

**Solution**:
```bash
# Check Docker service
sudo systemctl status docker

# Check logs
docker compose logs

# Restart Docker
sudo systemctl restart docker
```

### Problem: Database restore fails

**Solution**:
```bash
# Drop and recreate database
docker exec -it n8n_postgres psql -U n8n_user -c "DROP DATABASE n8n;"
docker exec -it n8n_postgres psql -U n8n_user -c "CREATE DATABASE n8n;"

# Restore again
docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n < backups/your_backup.dump
```

### Problem: n8n workflows not loading

**Solution**:
- Check if PostgreSQL is running: `docker ps | grep postgres`
- Verify database connection in n8n logs: `docker logs n8n`
- Ensure `.env` credentials match PostgreSQL settings

### Problem: Cloudflare Tunnel not working

**Solution**:
```bash
# Check cloudflared logs
docker logs cloudflared

# Verify tunnel token in .env
cat .env | grep CLOUDFLARE

# Restart tunnel
docker compose restart cloudflared
```

### Problem: Out of disk space

**Solution**:
```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a

# Clean old backups
rm backups/old_backup_*.dump
```

---

## Monitoring & Maintenance

### Daily Checks
- Monitor disk space: `df -h`
- Check container status: `docker compose ps`
- Review logs: `docker compose logs --tail=100`

### Weekly Checks
- Verify backup files exist: `ls -lh backups/`
- Test backup restore (on staging environment)
- Update Docker images: `docker compose pull && docker compose up -d`

### Monthly Checks
- System updates: `sudo apt update && sudo apt upgrade -y`
- Review firewall rules: `sudo ufw status numbered`
- Analyze database size: `docker exec n8n_postgres psql -U n8n_user -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"`

---

## Rollback Plan

If migration fails, you can rollback:

1. **Keep local environment running** (don't shut down)
2. **Document VPS issues** for troubleshooting
3. **Restore backup on local** if needed:
   ```bash
   docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n -c < backups/n8n_backup_latest.dump
   ```
4. **Retry migration** after fixing issues

---

## Next Steps After Migration

1. **Run first sync workflow** to ensure data pipeline works
2. **Monitor for 24-48 hours** to ensure stability
3. **Set up monitoring** (Uptime Kuma, Grafana, or Portainer)
4. **Configure alerts** (email/Telegram on workflow failures)
5. **Document VPS-specific settings** for team
6. **Decommission local environment** (after 1 week of stable operation)

---

## Support Resources

- **n8n Documentation**: https://docs.n8n.io
- **Docker Documentation**: https://docs.docker.com
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

---

**Migration Prepared By**: Claude Code
**Date**: 2025-12-04
**Branch**: claude/vps-migration-setup-01QnPMnJW83ejXWk8yh4Ybda
