# VPS Migration Resources - Quick Start

This directory contains all the resources you need to migrate your n8n stock trading automation system to a VPS.

## 📚 Documentation Files

| File | Description | When to Use |
|------|-------------|-------------|
| **[MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)** | Comprehensive checklist with every step | Use this as your primary guide |
| **[VPS_MIGRATION_GUIDE.md](VPS_MIGRATION_GUIDE.md)** | Detailed step-by-step instructions | Reference for detailed procedures |
| **[BACKUP_DATABASE.md](BACKUP_DATABASE.md)** | Database backup procedures | Before migration starts |

## 🛠️ Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **backup.sh** | Creates database backups (local) | `./backup.sh` |
| **vps-setup.sh** | Initial VPS configuration | `sudo bash vps-setup.sh` (on VPS) |
| **deploy-vps.sh** | Deploys project on VPS | `./deploy-vps.sh backups/file.dump` (on VPS) |

## 🚀 Quick Start (TL;DR)

### On Local Machine

```bash
# 1. Stop workflows in n8n UI

# 2. Create backup
./backup.sh

# 3. Transfer to VPS
scp .env backups/n8n_backup_*.dump user@VPS_IP:/home/user/stock_project/
```

### On VPS (As Root)

```bash
# 1. Run initial setup
sudo bash vps-setup.sh

# 2. Switch to non-root user
su - n8nuser

# 3. Clone repository
git clone https://github.com/ahmadhanimustafa/stock_project.git
cd stock_project
git checkout claude/vps-migration-setup-01QnPMnJW83ejXWk8yh4Ybda

# 4. Deploy
./deploy-vps.sh backups/n8n_backup_YYYYMMDD_HHMMSS.dump
```

### Verify

```bash
# Check services
docker compose ps

# Access n8n
# Open: https://your-domain.com or http://VPS_IP:5678
```

## 📋 Migration Workflow

```
┌─────────────────────────────────────────────────────────┐
│ Phase 1: Preparation (Local)                            │
│ • Stop workflows                                         │
│ • Run backup.sh                                          │
│ • Verify backup files                                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Phase 2: VPS Setup                                       │
│ • Provision VPS (Ubuntu 22.04)                          │
│ • Run vps-setup.sh                                       │
│ • Configure firewall & security                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Transfer Files                                  │
│ • Clone repository to VPS                                │
│ • Transfer .env and backup files                         │
│ • Update configuration for VPS                           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Deploy                                          │
│ • Run deploy-vps.sh                                      │
│ • Restore database                                       │
│ • Start all services                                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Phase 5: Verification                                    │
│ • Test n8n access                                        │
│ • Verify workflows                                       │
│ • Run test execution                                     │
│ • Set up automated backups                               │
└─────────────────────────────────────────────────────────┘
```

## ⏱️ Estimated Timeline

| Phase | Duration |
|-------|----------|
| Local preparation | 15-30 min |
| VPS initial setup | 30-60 min |
| File transfer | 15-30 min |
| Deployment | 20-30 min |
| Verification | 30-60 min |
| **Total** | **2-4 hours** |

## ✅ Pre-Migration Checklist (Essential)

- [ ] VPS provisioned (4GB RAM, 2 CPU, 50GB storage minimum)
- [ ] Domain DNS configured (if using custom domain)
- [ ] Local database backed up
- [ ] `.env` file copied to secure location
- [ ] All workflows stopped
- [ ] Cloudflare Tunnel token saved (if using)

## 🔐 Security Considerations

1. **Firewall**: UFW configured by `vps-setup.sh`
2. **SSH**: Password authentication disabled, key-based auth only
3. **Backups**: Automated daily backups via cron
4. **Secrets**: All sensitive data in `.env` (never committed to Git)
5. **SSL/TLS**: Handled by Cloudflare Tunnel (or Certbot/Nginx)

## 📊 What Gets Migrated

✅ **All Data**:
- n8n workflow definitions
- Historical OHLCV data (fact_daily_ohlcv)
- Technical indicators (fact_tech_indicators)
- Risk/reward metrics
- Trading logs
- Fundamentals data
- Configuration tables

✅ **Services**:
- PostgreSQL 15 database
- n8n workflow engine
- pgAdmin database UI
- Cloudflare Tunnel (if configured)
- Watchtower (auto-updates)

✅ **Configuration**:
- Environment variables (.env)
- Docker Compose setup
- Workflow credentials (may need API key re-entry)

## 🆘 Troubleshooting Quick Fixes

### Problem: Cannot SSH to VPS
```bash
# Check firewall
sudo ufw allow 22/tcp
sudo ufw enable
```

### Problem: Docker not found
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Problem: Database restore fails
```bash
# Drop and recreate database
docker exec n8n_postgres psql -U n8n_user -c "DROP DATABASE n8n;"
docker exec n8n_postgres psql -U n8n_user -c "CREATE DATABASE n8n;"

# Restore again
docker exec -i n8n_postgres pg_restore -U n8n_user -d n8n < backup.dump
```

### Problem: n8n won't start
```bash
# Check logs
docker logs n8n

# Verify PostgreSQL is running
docker exec n8n_postgres pg_isready -U n8n_user

# Restart all services
docker compose restart
```

### Problem: Workflows not loading
- Check database connection in n8n logs
- Verify credentials in `.env` match PostgreSQL
- Ensure database was restored successfully

## 📞 Support & Resources

- **n8n Docs**: https://docs.n8n.io
- **Docker Docs**: https://docs.docker.com
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/

## 📝 Important Notes

1. **Keep local environment running** until VPS is fully verified (1 week recommended)
2. **Test backup restore** before decommissioning local setup
3. **API Keys**: You may need to re-enter sensitive credentials in n8n after migration
4. **DNS Propagation**: Can take up to 48 hours for domain changes
5. **Backups**: Set up automated backups on VPS immediately after migration

## 🎯 Success Criteria

Migration is successful when:
- ✅ n8n accessible via domain
- ✅ All workflows visible and executable
- ✅ Database fully restored and verified
- ✅ Test workflow runs successfully
- ✅ Scheduled workflows running on time
- ✅ API integrations working (EODHD, OpenAI)
- ✅ Automated backups configured
- ✅ 1 week of stable operation

## 📂 File Structure

```
stock_project/
├── MIGRATION_README.md          ← You are here
├── MIGRATION_CHECKLIST.md       ← Detailed checklist
├── VPS_MIGRATION_GUIDE.md       ← Step-by-step guide
├── BACKUP_DATABASE.md           ← Backup procedures
├── backup.sh                    ← Local backup script
├── vps-setup.sh                 ← VPS initial setup (run on VPS)
├── deploy-vps.sh                ← Deployment script (run on VPS)
├── docker-compose.yml           ← Service definitions
├── .env                         ← Environment variables (DO NOT COMMIT)
├── backups/                     ← Database backups
│   └── n8n_backup_*.dump
└── source/                      ← Workflow JSONs and SQL schemas
```

## 🔄 Workflow After Migration

```bash
# Daily operations on VPS
docker compose ps              # Check service status
docker compose logs -f n8n     # View n8n logs
./backup.sh                    # Manual backup (auto via cron)

# Updating workflows
# Make changes in n8n UI, they're auto-saved to PostgreSQL

# Updating Docker images
docker compose pull
docker compose up -d

# Restarting services
docker compose restart
```

## 🔙 Rollback Plan

If migration fails:
1. Keep local environment running (don't stop!)
2. Document errors from VPS
3. Fix issues without affecting local
4. Retry migration
5. Only decommission local after 1 week of stable VPS operation

---

## Need Help?

1. **Read**: [VPS_MIGRATION_GUIDE.md](VPS_MIGRATION_GUIDE.md) for detailed instructions
2. **Follow**: [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) step by step
3. **Check**: Troubleshooting section in VPS_MIGRATION_GUIDE.md
4. **Logs**: `docker compose logs` for service issues

---

**Version**: 1.0
**Last Updated**: 2025-12-04
**Branch**: claude/vps-migration-setup-01QnPMnJW83ejXWk8yh4Ybda
**Prepared By**: Claude Code
