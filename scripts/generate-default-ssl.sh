#!/bin/bash
# Generate self-signed SSL certificate for nginx default server

set -e

echo "🔐 Generating self-signed SSL certificate for default server..."
echo ""

CERT_DIR="../certbot/conf/live/default"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

# Create directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Check if certificate already exists
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "⚠️  Certificate already exists!"
    echo ""
    read -p "Regenerate? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Certificate generation cancelled"
        exit 0
    fi
fi

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=default" \
    2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Self-signed certificate generated!"
    echo ""
    echo "Certificate: $CERT_FILE"
    echo "Private Key: $KEY_FILE"
    echo ""
    echo "Note: This certificate is only for the default server block."
    echo "      Use Let's Encrypt for production domains."
    echo ""
    echo "Certificate details:"
    openssl x509 -in "$CERT_FILE" -noout -text | grep -A2 "Subject:"
else
    echo "❌ Certificate generation failed!"
    exit 1
fi
