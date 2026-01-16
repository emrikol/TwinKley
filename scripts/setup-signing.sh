#!/bin/bash
#
# setup-signing.sh - Create a self-signed code signing certificate for TwinKley
#
# This script creates a self-signed certificate that provides stable code signing,
# so you don't have to re-grant Accessibility permissions after each rebuild.
#
# Usage:
#   ./scripts/setup-signing.sh [certificate-name]
#
# Default certificate name: "TwinKley Development"
#

set -e

# Configuration
CERT_NAME="${1:-TwinKley Development}"
KEYCHAIN="login.keychain-db"
TEMP_DIR=$(mktemp -d)
KEY_FILE="$TEMP_DIR/key.pem"
CERT_FILE="$TEMP_DIR/cert.pem"
P12_FILE="$TEMP_DIR/cert.p12"
P12_PASSWORD="temp$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}=== TwinKley Code Signing Setup ===${NC}"
echo

# Check if certificate already exists
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo -e "${YELLOW}Certificate '$CERT_NAME' already exists.${NC}"
    echo
    echo "Options:"
    echo "  1. Use existing certificate (recommended)"
    echo "  2. Delete and recreate"
    echo
    read -p "Choice [1]: " choice
    choice="${choice:-1}"

    if [[ "$choice" == "1" ]]; then
        echo -e "${GREEN}Using existing certificate.${NC}"
        echo
        echo "To sign your app, run:"
        echo -e "  ${BLUE}./build.sh -s \"$CERT_NAME\"${NC}"
        exit 0
    elif [[ "$choice" == "2" ]]; then
        echo "Deleting existing certificate..."
        security delete-certificate -c "$CERT_NAME" "$KEYCHAIN" 2>/dev/null || true
    else
        echo "Invalid choice. Exiting."
        exit 1
    fi
fi

echo -e "${BLUE}Creating self-signed code signing certificate: $CERT_NAME${NC}"
echo

# Step 1: Generate private key
echo "1. Generating private key..."
openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null

# Step 2: Create certificate signing request and self-signed cert
echo "2. Creating self-signed certificate..."
openssl req -new -x509 -key "$KEY_FILE" -out "$CERT_FILE" -days 3650 \
    -subj "/CN=$CERT_NAME/O=Local Development" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" \
    2>/dev/null

# Step 3: Create P12 bundle for import
echo "3. Packaging for keychain import..."
# Use -legacy for compatibility with macOS security tool (OpenSSL 3.x issue)
openssl pkcs12 -export -out "$P12_FILE" -inkey "$KEY_FILE" -in "$CERT_FILE" \
    -passout "pass:$P12_PASSWORD" -legacy 2>/dev/null

# Step 4: Import to keychain
echo "4. Importing to login keychain..."
security import "$P12_FILE" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign 2>/dev/null

# Step 5: Set partition list to allow codesign access without prompts
echo "5. Configuring keychain access..."
# This requires user password - we'll let security prompt for it
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" 2>/dev/null || {
    echo -e "${YELLOW}Note: You may need to enter your login password to allow codesign access.${NC}"
    echo "If prompted, enter your Mac login password."
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$KEYCHAIN" || true
}

echo
echo -e "${GREEN}=== Certificate created successfully! ===${NC}"
echo
echo "Certificate name: $CERT_NAME"
echo "Valid for: 10 years"
echo

# Verify
echo "Verifying certificate..."
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo -e "${GREEN}Certificate is ready for code signing.${NC}"
else
    echo -e "${RED}Warning: Certificate may not be properly configured for code signing.${NC}"
    echo "Try creating it manually via Keychain Access (see CONTRIBUTING.md)."
    exit 1
fi

echo
echo -e "${YELLOW}=== Manual Trust Required ===${NC}"
echo
echo "The certificate was imported but needs to be trusted for code signing."
echo "Opening Keychain Access..."
open -a "Keychain Access"
echo
echo "In Keychain Access:"
echo "  1. Select 'login' keychain in left sidebar"
echo "  2. Select 'Certificates' tab (or search '$CERT_NAME')"
echo "  3. Double-click '$CERT_NAME'"
echo "  4. Expand 'Trust' section"
echo "  5. Change 'Code Signing' to 'Always Trust'"
echo "  6. Close and enter your password"
echo
echo -e "${BLUE}After trusting, build with:${NC}"
echo -e "   ${GREEN}./build.sh -s \"$CERT_NAME\"${NC}"
