# qBittorrent Service 🧲

Pre-configured qBittorrent Docker deployment for the Synology NAS with auto-installed community search plugins.

## What's Included

- **Docker Compose** — linuxserver/qbittorrent with WebUI on port 8080
- **15 Search Plugins** — auto-installed on first boot via custom init script
- **Deploy Script** — one-command deploy to NAS

## Plugins Installed

| Plugin | Focus |
|--------|-------|
| ThePirateBay | General |
| Nyaa.si | Anime |
| EZTV | TV Shows |
| YTS | Movies |
| TorrentGalaxy | General |
| GloTorrents | General |
| KickassTorrents | General |
| Linux Tracker | Linux ISOs |
| Academic Torrents | Research |
| SolidTorrents | General |
| TorrentDownload | General |
| YourBittorrent | General |
| TheRarBg | General |
| Snowfl | Meta-search |
| BitSearch | General |

## Deployment

```bash
# Deploy to NAS
bash deploy.sh

# Dry run (validate only)
bash deploy.sh --dry-run
```

## Access

- **WebUI**: http://192.168.86.2:8080
- **Default user**: admin
- **Default password**: Check container logs on first run

```bash
ssh nas "sudo /usr/local/bin/docker logs qbittorrent 2>&1 | grep 'temporary password'"
```

## Integration

The tools-service connects to qBittorrent via its WebUI API. Set these env vars in tools-service:

```
QBITTORRENT_URL=http://192.168.86.2:8080
QBITTORRENT_USERNAME=admin
QBITTORRENT_PASSWORD=<your_password>
```

## Download Directory

Downloads are stored at `/volume1/downloads` on the NAS.
