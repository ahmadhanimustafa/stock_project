#!/bin/bash

# VPS Initial Setup Script for n8n Stock Project
# Run this script on your VPS after first login
# Usage: bash vps-setup.sh

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VPS Setup Script for n8n Stock Project      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Get username for non-root user
read -p "Enter username for non-root user (default: n8nuser): " USERNAME
USERNAME=${USERNAME:-n8nuser}

echo -e "${YELLOW}Step 1/8: Updating system packages...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}Step 2/8: Installing required tools...${NC}"
apt install -y git curl wget nano htop net-tools ufw fail2ban unzip

echo -e "${YELLOW}Step 3/8: Creating non-root user '$USERNAME'...${NC}"
if id "$USERNAME" &>/dev/null; then
    echo -e "${GREEN}User $USERNAME already exists, skipping...${NC}"
else
    adduser --disabled-password --gecos "" "$USERNAME"
    echo -e "${GREEN}User $USERNAME created${NC}"
    echo -e "${YELLOW}Please set password for $USERNAME:${NC}"
    passwd "$USERNAME"
fi

echo -e "${YELLOW}Step 4/8: Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Add user to docker group
usermod -aG docker "$USERNAME"
usermod -aG sudo "$USERNAME"

echo -e "${YELLOW}Step 5/8: Setting timezone to Asia/Jakarta...${NC}"
timedatectl set-timezone Asia/Jakarta
echo -e "${GREEN}✓ Timezone set: $(timedatectl | grep "Time zone")${NC}"

echo -e "${YELLOW}Step 6/8: Configuring firewall (UFW)...${NC}"
# Disable UFW first to prevent lockout
ufw --force disable

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (IMPORTANT!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP/HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Allow n8n port (optional)
read -p "Allow direct access to n8n on port 5678? (y/n, default: n): " ALLOW_N8N
if [[ "$ALLOW_N8N" =~ ^[Yy]$ ]]; then
    ufw allow 5678/tcp comment 'n8n'
fi

# Allow pgAdmin port (optional)
read -p "Allow direct access to pgAdmin on port 8080? (y/n, default: n): " ALLOW_PGADMIN
if [[ "$ALLOW_PGADMIN" =~ ^[Yy]$ ]]; then
    ufw allow 8080/tcp comment 'pgAdmin'
fi

# Enable firewall
ufw --force enable
echo -e "${GREEN}✓ Firewall configured and enabled${NC}"
ufw status numbered

echo -e "${YELLOW}Step 7/8: Configuring SSH security...${NC}"
# Backup SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Update SSH config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd
echo -e "${GREEN}✓ SSH security configured${NC}"

echo -e "${YELLOW}Step 8/8: Setting up fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban
echo -e "${GREEN}✓ fail2ban enabled${NC}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           VPS Setup Complete! ✓                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  ✓ System packages updated"
echo "  ✓ Docker installed and running"
echo "  ✓ User '$USERNAME' created and added to docker group"
echo "  ✓ Timezone set to Asia/Jakarta"
echo "  ✓ Firewall configured and enabled"
echo "  ✓ SSH security hardened"
echo "  ✓ fail2ban enabled"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy your SSH key to the new user:"
echo "   ${BLUE}ssh-copy-id $USERNAME@$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo "2. Switch to new user and clone repository:"
echo "   ${BLUE}su - $USERNAME${NC}"
echo "   ${BLUE}git clone https://github.com/ahmadhanimustafa/stock_project.git${NC}"
echo "   ${BLUE}cd stock_project${NC}"
echo ""
echo "3. Transfer .env file and database backup"
echo ""
echo "4. Follow VPS_MIGRATION_GUIDE.md starting from Phase 3"
echo ""
echo -e "${RED}IMPORTANT: Log out and log back in for group changes to take effect${NC}"
echo ""
