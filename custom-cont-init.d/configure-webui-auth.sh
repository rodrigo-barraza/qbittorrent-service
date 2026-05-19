#!/bin/bash
# ============================================================
# Pre-configure qBittorrent WebUI credentials on boot
#
# Uses WEBUI_USERNAME / WEBUI_PASSWORD env vars to set auth
# credentials in qBittorrent.conf before the daemon starts.
# This avoids the random temp password on first boot and
# ensures tools-service can authenticate immediately.
#
# qBittorrent stores the password as a PBKDF2-SHA512 hash:
#   @ByteArray(SALT:HASH)
# We use Python (bundled in the image) to generate this.
# ============================================================

CONF_DIR="/config/qBittorrent"
CONF_FILE="${CONF_DIR}/qBittorrent.conf"

USERNAME="${WEBUI_USERNAME:-admin}"
PASSWORD="${WEBUI_PASSWORD:-}"

if [ -z "$PASSWORD" ]; then
  echo "⚙️  [auth-init] WEBUI_PASSWORD not set — skipping credential injection"
  exit 0
fi

echo "⚙️  [auth-init] Configuring WebUI credentials (user: ${USERNAME})"

# Generate PBKDF2-SHA512 hash using Python (available in the image)
HASH_LINE=$(python3 -c "
import hashlib, os, base64
salt = os.urandom(16)
iterations = 100000
dk = hashlib.pbkdf2_hmac('sha512', b'${PASSWORD}', salt, iterations)
salt_b64 = base64.b64encode(salt).decode()
hash_b64 = base64.b64encode(dk).decode()
print(f'@ByteArray({salt_b64}:{hash_b64})')
")

if [ -z "$HASH_LINE" ]; then
  echo "⚙️  [auth-init] ❌ Failed to generate password hash"
  exit 1
fi

# Ensure config directory exists
mkdir -p "$CONF_DIR"

# Create config file if it doesn't exist
if [ ! -f "$CONF_FILE" ]; then
  cat > "$CONF_FILE" << EOF
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Username=${USERNAME}
WebUI\Password_PBKDF2=${HASH_LINE}
EOF
  echo "⚙️  [auth-init] ✅ Created config with credentials"
else
  # Update existing config — replace or inject username and password
  if grep -q "WebUI\\\\Username" "$CONF_FILE"; then
    sed -i "s|^WebUI\\\\Username=.*|WebUI\\\\Username=${USERNAME}|" "$CONF_FILE"
  else
    # Add under [Preferences] section
    if grep -q "\[Preferences\]" "$CONF_FILE"; then
      sed -i "/\[Preferences\]/a WebUI\\\\Username=${USERNAME}" "$CONF_FILE"
    else
      echo -e "\n[Preferences]\nWebUI\\\\Username=${USERNAME}" >> "$CONF_FILE"
    fi
  fi

  if grep -q "WebUI\\\\Password_PBKDF2" "$CONF_FILE"; then
    sed -i "s|^WebUI\\\\Password_PBKDF2=.*|WebUI\\\\Password_PBKDF2=${HASH_LINE}|" "$CONF_FILE"
  else
    if grep -q "\[Preferences\]" "$CONF_FILE"; then
      sed -i "/\[Preferences\]/a WebUI\\\\Password_PBKDF2=${HASH_LINE}" "$CONF_FILE"
    else
      echo "WebUI\\Password_PBKDF2=${HASH_LINE}" >> "$CONF_FILE"
    fi
  fi

  echo "⚙️  [auth-init] ✅ Updated existing config with credentials"
fi
