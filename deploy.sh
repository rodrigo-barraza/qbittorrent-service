#!/bin/bash
# ============================================================
# qBittorrent — Build & Deploy to Synology NAS
#
# Pre-built image from linuxserver.io — no local docker build.
# Build phase = pull image on NAS.
# Deploy phase = sync compose + init scripts, restart container.
#
# Compatible with deploy-kit/deploy-all.sh phase system:
#   --build-only   → pull latest image on NAS
#   --deploy-only  → sync files + restart
#   (no flag)      → full pipeline
#
# Usage:
#   bash deploy.sh
#   bash deploy.sh --build-only
#   bash deploy.sh --deploy-only
#   bash deploy.sh --dry-run
#   bash deploy.sh --skip-pull
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="qbittorrent-service"
DISPLAY_NAME="🧲 qBittorrent"
REMOTE_IMAGE="lscr.io/linuxserver/qbittorrent:latest"

# ── Deploy target (set by deploy-all.sh or fallback) ─────────
SSH_HOST="${DEPLOY_SSH_HOST:-nas}"
COMPOSE_DIR="${DEPLOY_COMPOSE_ROOT:-/volume1/docker}/${IMAGE_NAME}"
DOCKER_BIN="${DEPLOY_DOCKER_BIN:-/usr/local/bin/docker}"

# ── Flags ─────────────────────────────────────────────────────
DRY_RUN=false
BUILD_ONLY=false
DEPLOY_ONLY=false
SKIP_PULL=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=true ;;
    --build-only)   BUILD_ONLY=true ;;
    --deploy-only)  DEPLOY_ONLY=true ;;
    --skip-pull)    SKIP_PULL=true ;;
    --no-cache)     ;; # Not applicable for pre-built images
  esac
done

echo "${DISPLAY_NAME} — Deploying to ${SSH_HOST}"
echo "   Compose dir: ${COMPOSE_DIR}"
echo "   Image: ${REMOTE_IMAGE}"

# ── Validate ──────────────────────────────────────────────────
if [ ! -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
  echo "ERROR: docker-compose.yml not found" >&2
  exit 1
fi

if $DRY_RUN; then
  echo "   ✅ Dry run — validation passed"
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# BUILD PHASE — Pull latest image on NAS
# ══════════════════════════════════════════════════════════════
if ! $DEPLOY_ONLY; then
  if $SKIP_PULL; then
    echo "   ⏭  Skipping image pull (--skip-pull)"
  else
    echo "   ⬇️  Pulling ${REMOTE_IMAGE} on NAS..."
    ssh "$SSH_HOST" "sudo ${DOCKER_BIN} pull ${REMOTE_IMAGE}"
    echo "   ✅ Image pulled"
  fi

  if $BUILD_ONLY; then
    echo "   ✅ Build phase complete (image pulled)"
    exit 0
  fi
fi

# ══════════════════════════════════════════════════════════════
# DEPLOY PHASE — Sync files + restart container
# ══════════════════════════════════════════════════════════════

# ── Create remote directory ──────────────────────────────────
echo "   📁 Ensuring remote directory..."
ssh "$SSH_HOST" "mkdir -p '${COMPOSE_DIR}/config' 2>/dev/null || sudo mkdir -p '${COMPOSE_DIR}/config'"

# ── Sync compose file ────────────────────────────────────────
echo "   📦 Syncing docker-compose.yml..."
cat "${SCRIPT_DIR}/docker-compose.yml" | ssh "$SSH_HOST" "cat > '${COMPOSE_DIR}/docker-compose.yml'"

# ── Sync custom init scripts (plugin auto-installer) ─────────
if [ -d "${SCRIPT_DIR}/custom-cont-init.d" ]; then
  echo "   🔌 Syncing custom-cont-init.d/..."
  ssh "$SSH_HOST" "mkdir -p '${COMPOSE_DIR}/custom-cont-init.d'"
  for f in "${SCRIPT_DIR}/custom-cont-init.d/"*.sh; do
    [ -f "$f" ] || continue
    fname="$(basename "$f")"
    cat "$f" | ssh "$SSH_HOST" "cat > '${COMPOSE_DIR}/custom-cont-init.d/${fname}' && chmod +x '${COMPOSE_DIR}/custom-cont-init.d/${fname}'"
    echo "      → ${fname}"
  done
fi

# ── Create downloads directory ────────────────────────────────
echo "   📁 Ensuring /volume1/downloads..."
ssh "$SSH_HOST" "mkdir -p /volume1/downloads 2>/dev/null || sudo mkdir -p /volume1/downloads"

# ── Restart container ─────────────────────────────────────────
echo "   🔄 Restarting container..."
COMPOSE_OUTPUT=$(ssh "$SSH_HOST" "cd '${COMPOSE_DIR}' && sudo ${DOCKER_BIN} compose down --remove-orphans 2>&1 && sudo ${DOCKER_BIN} compose up -d 2>&1" 2>&1)
echo "$COMPOSE_OUTPUT" | sed 's/^/      /'

# ── Fix ownership (linuxserver s6-overlay requirements) ───────
echo "   🔒 Fixing container permissions..."
ssh "$SSH_HOST" "sudo ${DOCKER_BIN} exec -u root qbittorrent-service sh -c '\
  chmod 755 /config && \
  chown -R 1026:100 /config && \
  mkdir -p /config/.cache/qBittorrent && \
  chown -R 1026:100 /config/.cache && \
  chown -R root:root /custom-cont-init.d'" 2>/dev/null || true

# ── Verify ────────────────────────────────────────────────────
echo "   ⏳ Waiting 10s for startup..."
sleep 10

CONTAINER_STATUS=$(ssh "$SSH_HOST" "sudo ${DOCKER_BIN} ps --filter 'name=qbittorrent-service' --format '{{.Status}}'" 2>/dev/null || true)
if echo "$CONTAINER_STATUS" | grep -qi "up"; then
  echo "   ✅ qBittorrent is running: ${CONTAINER_STATUS}"
else
  echo "   ❌ Container not healthy: ${CONTAINER_STATUS:-'not found'}" >&2
  exit 1
fi

echo "   🎉 Deploy complete — WebUI: http://192.168.86.2:8080"
