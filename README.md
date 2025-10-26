# zwfm-icecast

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This repository contains an automated installer and configuration script for [Icecast2](https://icecast.org/), the open-source streaming media server. This installer is used by [ZuidWest FM](https://www.zuidwestfm.nl/), [Radio Rucphen](https://www.rucphenrtv.nl/), and [BredaNu](https://www.bredanu.nl/) in the Netherlands to quickly deploy streaming infrastructure. The script handles complete system setup including optional SSL/TLS certificates via Let's Encrypt.

Icecast serves as the public-facing streaming endpoint for our [Liquidsoap-based streaming solution](https://github.com/oszuidwest/zwfm-liquidsoap), providing MP3 and AAC streams to listeners. It also works with any other streaming encoder or broadcasting software that supports Icecast protocol, including FFmpeg, Butt (Broadcast Using This Tool), Rocket Broadcaster, and many others.

# Features
- **Fully automated installation**: Single script handles package installation, configuration, and service setup
- **SSL/TLS support**: Automatic Let's Encrypt certificate provisioning with auto-renewal hooks
- **Multiple hostname support**: Configure one or more hostnames
- **Bot protection**: Automatically generates robots.txt to prevent search engine crawlers from consuming bandwidth
- **Hardening**: Configures system capabilities for port binding, prevents indexing via HTTP headers
- **Production-ready defaults**: Optimized for high-capacity streaming (5000 clients, 25 sources)

# Installation
- Ensure you have a fresh Debian or Ubuntu-based Linux system (64-bit)
- Gain root access with `sudo su`
- Download and execute the install script using `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwfm-icecast/main/install.sh)"`

The script will prompt you for:
- **Hostname(s)**: Domain name(s) for your server (e.g., `stream.example.com`)
- **Passwords**: Source/relay password and admin password
- **Location**: Server location (displayed on admin pages)
- **Admin email**: Contact email (used for Let's Encrypt)
- **Port**: Icecast listening port (default: 80)
- **SSL**: Whether to obtain a Let's Encrypt certificate
- **OS updates**: Whether to perform system updates

# Multiple Hostname Support
You can configure multiple hostnames by separating them with spaces when prompted (e.g., `stream.example.com stream2.example.com`). The first hostname becomes the primary hostname used in Icecast's configuration. When SSL is enabled, a single Let's Encrypt certificate will be obtained covering all specified hostnames, allowing your Icecast server to respond to multiple domain names. All hostnames must point to the same server's IP address via DNS A/AAAA records.

# SSL/TLS Configuration
SSL certificate provisioning is only available when Icecast runs on port 80, as Let's Encrypt requires HTTP-01 validation. If enabled, the installer will:
- Obtain certificates for all specified hostnames
- Configure Icecast to listen on both port 80 (HTTP) and port 443 (HTTPS)
- Create an automatic renewal hook at `/etc/letsencrypt/renewal-hooks/deploy/icecast2.sh`
- Concatenate the certificate chain and private key into `/usr/share/icecast2/icecast.pem`

Certificates automatically renew via Certbot's systemd timer. Test renewal with `certbot renew --dry-run`.

# Post-Installation
After installation, your Icecast server will be accessible at:
- **Admin interface**: `http://your-hostname:port/admin/` (username: `admin`)
- **Stream status**: `http://your-hostname:port/status.xsl`

Key configuration files:
- **Main config**: `/etc/icecast2/icecast.xml`
- **Webroot**: `/usr/share/icecast2/web`
- **Logs**: `/var/log/icecast2/` (or view with `journalctl -u icecast2 -f`)

Essential commands:
- Restart Icecast: `systemctl restart icecast2`
- View logs: `journalctl -u icecast2 -f`
- Edit configuration: `nano /etc/icecast2/icecast.xml` (restart required after changes)

# Default Configuration
The installer configures Icecast with:
- **Capacity**: 5000 concurrent clients, 25 source connections
- **Burst size**: 265536 bytes for initial buffering
- **CORS**: Enabled via `Access-Control-Allow-Origin: *` header
- **Search engine blocking**: Fully blocked via both `X-Robots-Tag: noindex, noarchive` HTTP header and `robots.txt`
- **Timezone**: Europe/Amsterdam

# Connecting Stream Sources
Icecast accepts streams from any encoder that supports the Icecast protocol. Configure your broadcasting software with:
- **Host**: Your server's hostname
- **Port**: The configured port (80, 443, or custom)
- **Mount point**: The stream path (e.g., `/live`)
- **Source password**: The password you specified during installation

Common encoders that work with Icecast include:
- [Liquidsoap](https://github.com/oszuidwest/zwfm-liquidsoap) - Professional audio streaming with failover (used by ZuidWest FM, Radio Rucphen, and BredaNu)
- [FFmpeg](https://ffmpeg.org/) - Command-line encoding and streaming
- [Butt](https://danielnoethen.de/butt/) - Easy-to-use GUI broadcaster
- [Rocket Broadcaster](https://www.rocketbroadcaster.com/) - Windows broadcasting software
- Any other Icecast-compatible encoder 

# Shared Functions Library
This installer uses the [bash-functions](https://github.com/oszuidwest/bash-functions) library maintained by ZuidWest for common tasks like user prompts, package installation, and OS updates. The library is downloaded automatically at runtime.
