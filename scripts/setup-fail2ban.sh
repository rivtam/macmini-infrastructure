#!/bin/bash
# Setup Fail2ban on the host system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🛡️  Fail2ban Setup Script"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Run with: sudo ./scripts/setup-fail2ban.sh"
    exit 1
fi

# Check OS
if [ ! -f /etc/os-release ]; then
    echo -e "${RED}❌ Cannot detect OS${NC}"
    exit 1
fi

source /etc/os-release

echo "Detected OS: $NAME $VERSION"
echo ""

# Install fail2ban
echo "Installing fail2ban..."

if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
    apt-get update
    apt-get install -y fail2ban
elif [[ "$ID" == "centos" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "fedora" ]]; then
    yum install -y epel-release
    yum install -y fail2ban fail2ban-systemd
else
    echo -e "${YELLOW}⚠️  Unsupported OS. Please install fail2ban manually.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Fail2ban installed${NC}"
echo ""

# Copy configuration
echo "Copying configuration..."

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cp "$INFRA_DIR/fail2ban/jail.local" /etc/fail2ban/jail.local
mkdir -p /etc/fail2ban/filter.d
cp "$INFRA_DIR/fail2ban/filter.d/"* /etc/fail2ban/filter.d/

echo -e "${GREEN}✅ Configuration copied${NC}"
echo ""

# Enable and start fail2ban
echo "Starting fail2ban..."

systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${GREEN}✅ Fail2ban started${NC}"
echo ""

# Show status
echo "Fail2ban status:"
fail2ban-client status

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fail2ban setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Useful commands:"
echo "  fail2ban-client status                  # List all jails"
echo "  fail2ban-client status nginx-http-auth  # Status of specific jail"
echo "  fail2ban-client set nginx-http-auth unbanip <IP>  # Unban IP"
echo "  tail -f /var/log/fail2ban.log          # View logs"
echo ""
