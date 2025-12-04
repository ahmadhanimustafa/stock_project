# Database Backup Guide for Windows

This guide explains how to backup your PostgreSQL database on Windows before VPS migration.

## Prerequisites

- Docker Desktop for Windows installed and running
- Git Bash or PowerShell
- n8n containers running

## Quick Backup Methods

### Method 1: Using Batch File (Easiest)

Double-click `backup-windows.bat` or run from Command Prompt:

```cmd
backup-windows.bat
```

This will:
- Create compressed `.dump` backup
- Create SQL `.sql` backup
- Verify both backups
- Store in `backups/` folder

### Method 2: Using Git Bash

Open Git Bash and run:

```bash
./backup-windows.sh
```

### Method 3: Manual Docker Commands

Open PowerShell or Command Prompt:

```cmd
# Create backup directory
mkdir backups

# Create compressed backup
docker exec n8n_postgres pg_dump -U n8n_user -d n8n -F c > backups/n8n_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.dump

# Create SQL backup
docker exec n8n_postgres pg_dump -U n8n_user -d n8n > backups/n8n_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.sql
```

## Troubleshooting Windows Issues

### Issue: "No such file or directory" error

This happens when Docker tries to write to Windows temp paths incorrectly.

**Solution**: Use the Windows-specific scripts (`backup-windows.bat` or `backup-windows.sh`) which write directly to the host filesystem.

### Issue: Permission denied

**Solution**: Run Command Prompt or PowerShell as Administrator:
1. Right-click Command Prompt
2. Select "Run as administrator"
3. Navigate to project: `cd C:\container\stock_project`
4. Run backup: `backup-windows.bat`

### Issue: Docker not found

**Solution**: Ensure Docker Desktop is running and restart your terminal.

### Issue: Line ending problems in Git Bash

**Solution**: Convert line endings:
```bash
dos2unix backup-windows.sh
./backup-windows.sh
```

Or run directly:
```bash
bash -c "$(cat backup-windows.sh | dos2unix)"
```

## Verify Backup

After backup completes:

```cmd
# List backup files
dir backups

# Check file sizes (should be > 0)
dir backups\*.dump
dir backups\*.sql
```

Both files should have size greater than 0 KB.

## Transfer Backup to VPS

### Option 1: Using WinSCP (Recommended for Windows)

1. Download and install [WinSCP](https://winscp.net/)
2. Connect to your VPS
3. Navigate to `C:\container\stock_project\backups`
4. Drag and drop backup files to VPS `/home/user/stock_project/backups/`

### Option 2: Using scp from Git Bash

```bash
# From Git Bash
scp backups/n8n_backup_*.dump user@YOUR_VPS_IP:/home/user/stock_project/backups/
```

### Option 3: Using Cloud Storage

Upload to Dropbox/Google Drive/OneDrive, then download on VPS:

```bash
# On VPS
cd ~/stock_project/backups
wget "YOUR_SHARED_LINK" -O n8n_backup.dump
```

## PowerShell Backup Script (Alternative)

Create `backup.ps1`:

```powershell
# Set configuration
$BackupDir = "backups"
$ContainerName = "n8n_postgres"
$DBUser = "n8n_user"
$DBName = "n8n"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Create backup directory
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

# Check if container is running
$containerRunning = docker ps | Select-String $ContainerName
if (-not $containerRunning) {
    Write-Host "ERROR: Container $ContainerName is not running" -ForegroundColor Red
    exit 1
}

Write-Host "Creating backups..." -ForegroundColor Yellow

# Create compressed backup
docker exec $ContainerName pg_dump -U $DBUser -d $DBName -F c | Set-Content -Path "$BackupDir\n8n_backup_$Timestamp.dump" -Encoding Byte

# Create SQL backup
docker exec $ContainerName pg_dump -U $DBUser -d $DBName | Set-Content -Path "$BackupDir\n8n_backup_$Timestamp.sql"

Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host "Files saved in: $BackupDir\"
```

Run in PowerShell:
```powershell
.\backup.ps1
```

## Recommended Workflow for Windows Users

1. **Stop workflows** in n8n web UI
2. **Run backup**: Double-click `backup-windows.bat`
3. **Verify**: Check `backups\` folder for files
4. **Copy to USB drive** as extra backup
5. **Transfer to VPS** using WinSCP
6. **Keep local backup** until VPS migration is verified

## File Locations on Windows

- Project: `C:\container\stock_project\`
- Backups: `C:\container\stock_project\backups\`
- .env file: `C:\container\stock_project\.env`

## Important Notes for Windows

1. **Line Endings**: Git Bash scripts may need `dos2unix` conversion
2. **Paths**: Use backslashes `\` in Windows commands, forward slashes `/` in Git Bash
3. **Permissions**: Run as Administrator if you get permission errors
4. **Docker Desktop**: Must be running before backup
5. **File Names**: Windows-generated backups will have different timestamp format

## Next Steps

After successful backup:
1. Read [VPS_MIGRATION_GUIDE.md](VPS_MIGRATION_GUIDE.md)
2. Follow [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)
3. Transfer files to VPS
4. Deploy using provided scripts

## Common Windows-Specific Errors

### Error: "docker: command not found"
- Docker Desktop not installed or not in PATH
- Restart terminal after installing Docker Desktop

### Error: "Access is denied"
- Run terminal as Administrator
- Check Docker Desktop is running

### Error: "Cannot find the path specified"
- Use full path: `C:\container\stock_project\backups\`
- Create directory first: `mkdir backups`

### Error: Backup file is 0 bytes
- Check Docker container is running: `docker ps`
- Check database connection: `docker exec n8n_postgres pg_isready -U n8n_user`
- Check Docker logs: `docker logs n8n_postgres`

## Support

If backup still fails:
1. Share error message
2. Check Docker Desktop status
3. Verify PostgreSQL container running: `docker ps | findstr postgres`
4. Check container logs: `docker logs n8n_postgres`
