# zwfm-icecast

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Automated installer for [Icecast2](https://icecast.org/) with optional SSL/TLS via Let's Encrypt. Used by [ZuidWest FM](https://www.zuidwestfm.nl/), [Radio Rucphen](https://www.rucphenrtv.nl/), and [BredaNu](https://www.bredanu.nl/).

Icecast serves as the public-facing streaming endpoint for our [Liquidsoap-based streaming solution](https://github.com/oszuidwest/zwfm-liquidsoap), providing MP3 and AAC streams to listeners. It also works with any other streaming encoder or broadcasting software that supports Icecast protocol, including FFmpeg, Butt (Broadcast Using This Tool), Rocket Broadcaster, and many others.
Pairs perfectly with [zwfm-liquidsoap](https://github.com/oszuidwest/zwfm-liquidsoap) for a complete streaming solution. Works with any Icecast-compatible encoder (FFmpeg, Butt, Rocket Broadcaster, etc.).

# Features
- Fully automated installation and service setup
- SSL/TLS via Let's Encrypt with auto-renewal
- Multiple hostname support with DNS validation
- Bot protection (robots.txt, indexing headers)
- Privileged port binding without root
- Production defaults: 5000 clients, 25 sources
- Automatic log rotation (64 MB) with date-stamped archives
- Configuration validation (XML syntax checking)

# Installation

Debian/Ubuntu 64-bit system required. Run as root:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwfm-icecast/main/install.sh)"
```

Prompts for: hostname(s), passwords, location, admin email, port, timezone, SSL, OS updates.

The installer validates DNS resolution for all hostnames and warns if they don't resolve (important for Let's Encrypt).

# Multiple Hostnames

Space-separated hostnames (e.g., `stream.example.com stream2.example.com`). First becomes primary. Single SSL certificate covers all when enabled. All must point to same IP.

# SSL/TLS

Only available on port 80 (Let's Encrypt HTTP-01 validation). Obtains certificates for all hostnames, listens on 80 and 443, auto-renewal via Certbot. Test with `certbot renew --dry-run`.

# Post-Installation

Admin: `http://your-hostname:port/admin/` (user: admin)
Status: `http://your-hostname:port/status.xsl`

| File/Command | Path |
|---|---|
| Config | `/etc/icecast2/icecast.xml` |
| Webroot | `/usr/share/icecast2/web` |
| Logs | `/var/log/icecast2/` |
| Restart | `systemctl restart icecast2` |
| View logs | `journalctl -u icecast2 -f` |

# Default Configuration

| Setting | Value |
|---|---|
| Capacity | 5000 clients, 25 sources |
| Burst size | 265536 bytes |
| CORS | Enabled |
| Search engines | Blocked (robots.txt + headers) |
| Timezone | Configurable (default: Europe/Amsterdam) |
| Log rotation | 64 MB per file |
| Log archival | Date-stamped, indefinite retention |
| Log level | Error only |
| Log location | `/var/log/icecast2/` |

# Connecting Stream Sources

Configure encoder with:
- **Host**: Server hostname
- **Port**: Configured port (80, 443, or custom)
- **Mount point**: Stream path (e.g., `/live`)
- **Source password**: Password from installation

Compatible encoders: [Liquidsoap](https://github.com/oszuidwest/zwfm-liquidsoap), [FFmpeg](https://ffmpeg.org/), [Butt](https://danielnoethen.de/butt/), [Rocket Broadcaster](https://www.rocketbroadcaster.com/), or any Icecast-compatible encoder.

# Shared Functions Library

Uses [bash-functions](https://github.com/oszuidwest/bash-functions) library for user prompts, package installation, and OS updates. Downloaded automatically at runtime.
