#!/bin/bash
# ============================================================
# Auto-install community search plugins for qBittorrent
#
# This script runs on every container start via linuxserver's
# custom-cont-init.d hook. It downloads popular public torrent
# site search plugins into the nova3 engines directory.
#
# Plugins are Python scripts from the qBittorrent community:
# https://github.com/qbittorrent/search-plugins/wiki/Unofficial-search-plugins
# ============================================================

PLUGIN_DIR="/config/qBittorrent/nova3/engines"
# Legacy path (pre-v5) — kept as symlink for compatibility
LEGACY_PLUGIN_DIR="/config/qBittorrent/data/nova3/engines"

echo "🧲 [plugin-init] Installing community search plugins..."

# Create plugin directory if it doesn't exist
mkdir -p "$PLUGIN_DIR"

# ── Plugin Registry ──────────────────────────────────────────
# Format: URL | filename
# Only public sites that require no login/registration
PLUGINS=(
  # ThePirateBay — general purpose
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/thepiratebay.py|thepiratebay.py"

  # Nyaa.si — anime/manga
  "https://raw.githubusercontent.com/MadeOfMagicAndWires/qBit-plugins/master/engines/nyaasi.py|nyaasi.py"

  # EZTV — TV shows
  "https://raw.githubusercontent.com/DrPurp/eztvx-qbittorrent-plugin/main/eztvx.py|eztvx.py"

  # YTS — movies (YIFY)
  "https://codeberg.org/lazulyra/qbit-plugins/raw/branch/main/yts/yts.py|yts.py"

  # TorrentGalaxy — general purpose
  "https://raw.githubusercontent.com/nindogo/qbtSearchScripts/master/torrentgalaxy.py|torrentgalaxy.py"

  # GloTorrents — general purpose
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/glotorrents.py|glotorrents.py"

  # Kickass Torrents — general purpose
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/kickasstorrents.py|kickasstorrents.py"

  # Linux Tracker — Linux ISOs
  "https://raw.githubusercontent.com/MadeOfMagicAndWires/qBit-plugins/master/engines/linuxtracker.py|linuxtracker.py"

  # Academic Torrents — research papers, datasets
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/academictorrents.py|academictorrents.py"

  # SolidTorrents — general purpose
  "https://raw.githubusercontent.com/BurningMop/qBittorrent-Search-Plugins/main/solidtorrents.py|solidtorrents.py"

  # TorrentDownload — general purpose
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/torrentdownload.py|torrentdownload.py"

  # YourBittorrent — general purpose
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/yourbittorrent.py|yourbittorrent.py"

  # The RarBg — general purpose
  "https://raw.githubusercontent.com/BurningMop/qBittorrent-Search-Plugins/main/therarbg.py|therarbg.py"

  # Snowfl — meta-search aggregator
  "https://raw.githubusercontent.com/LightDestory/qBittorrent-Search-Plugins/master/src/engines/snowfl.py|snowfl.py"

  # Bit Search — general purpose
  "https://raw.githubusercontent.com/BurningMop/qBittorrent-Search-Plugins/main/bitsearch.py|bitsearch.py"
)

# ── Download plugins ─────────────────────────────────────────
INSTALLED=0
SKIPPED=0
FAILED=0

for entry in "${PLUGINS[@]}"; do
  IFS='|' read -r url filename <<< "$entry"
  target="${PLUGIN_DIR}/${filename}"

  if [ -f "$target" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if curl -fsSL --connect-timeout 10 --max-time 30 "$url" -o "$target" 2>/dev/null; then
    INSTALLED=$((INSTALLED + 1))
    echo "   ✅ ${filename}"
  else
    FAILED=$((FAILED + 1))
    echo "   ❌ ${filename} — download failed"
    rm -f "$target" 2>/dev/null
  fi
done

echo "🧲 [plugin-init] Done: ${INSTALLED} installed, ${SKIPPED} already present, ${FAILED} failed"
echo "   Plugin directory: ${PLUGIN_DIR}"
echo "   Total plugins: $(ls -1 "$PLUGIN_DIR"/*.py 2>/dev/null | wc -l)"
