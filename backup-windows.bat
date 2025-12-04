@echo off
REM Database Backup Script for n8n PostgreSQL (Windows)
REM Works with Docker Desktop on Windows

setlocal enabledelayedexpansion

echo ========================================
echo n8n Database Backup Script (Windows)
echo ========================================
echo.

REM Configuration
set BACKUP_DIR=backups
set CONTAINER_NAME=n8n_postgres
set DB_USER=n8n_user
set DB_NAME=n8n

REM Generate timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set TIMESTAMP=%dt:~0,4%%dt:~4,2%%dt:~6,2%_%dt:~8,2%%dt:~10,2%%dt:~12,2%

echo Timestamp: %TIMESTAMP%
echo.

REM Create backup directory
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Check if PostgreSQL container is running
docker ps | findstr "%CONTAINER_NAME%" >nul
if errorlevel 1 (
    echo ERROR: PostgreSQL container '%CONTAINER_NAME%' is not running
    echo Start it with: docker compose up -d postgres
    pause
    exit /b 1
)

echo Step 1/3: Creating compressed backup (.dump)...
docker exec %CONTAINER_NAME% pg_dump -U %DB_USER% -d %DB_NAME% -F c > "%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.dump"
if errorlevel 1 (
    echo ERROR: Failed to create compressed backup
    pause
    exit /b 1
)
echo SUCCESS: Compressed backup created

echo.
echo Step 2/3: Creating SQL backup (.sql)...
docker exec %CONTAINER_NAME% pg_dump -U %DB_USER% -d %DB_NAME% > "%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.sql"
if errorlevel 1 (
    echo ERROR: Failed to create SQL backup
    pause
    exit /b 1
)
echo SUCCESS: SQL backup created

echo.
echo Step 3/3: Verifying backups...
if exist "%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.dump" (
    for %%A in ("%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.dump") do set DUMP_SIZE=%%~zA
    echo Dump backup size: !DUMP_SIZE! bytes
) else (
    echo ERROR: Dump backup file not found
    pause
    exit /b 1
)

if exist "%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.sql" (
    for %%A in ("%BACKUP_DIR%\n8n_backup_%TIMESTAMP%.sql") do set SQL_SIZE=%%~zA
    echo SQL backup size: !SQL_SIZE! bytes
) else (
    echo ERROR: SQL backup file not found
    pause
    exit /b 1
)

echo.
echo ========================================
echo Backup completed successfully!
echo ========================================
echo.
echo Backup files:
echo - %BACKUP_DIR%\n8n_backup_%TIMESTAMP%.dump
echo - %BACKUP_DIR%\n8n_backup_%TIMESTAMP%.sql
echo.
echo Next steps:
echo 1. Copy backup to VPS using WinSCP or similar
echo 2. Or upload to cloud storage
echo 3. Keep local backup for safety
echo.
pause
