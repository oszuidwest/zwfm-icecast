#!/usr/bin/env bash

# Load the functions library
FUNCTIONS_LIB_PATH=$(mktemp)
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"

# Clean up temporary file on exit
trap 'rm -f "${FUNCTIONS_LIB_PATH}"' EXIT

# Download the functions library
if ! curl -sLo "${FUNCTIONS_LIB_PATH}" "${FUNCTIONS_LIB_URL}"; then
  echo -e "*** Failed to download the functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions library
# shellcheck source=/dev/null
source "${FUNCTIONS_LIB_PATH}"

# Define constants
ICECAST_CONFIG_DIR="/etc/icecast2"
ICECAST_XML="${ICECAST_CONFIG_DIR}/icecast.xml"
ICECAST_WEBROOT="/usr/share/icecast2/web"
ICECAST_PEM_PATH="/usr/share/icecast2/icecast.pem"
LETSENCRYPT_HOOKS_DIR="/etc/letsencrypt/renewal-hooks/deploy"

# Environment setup
set_colors
assert_user_privileged "root"
assert_os_linux
assert_os_64bit

# Display a welcome banner
clear
cat << "EOF"
 ______     _     ___          __       _     ______ __  __ 
|___  /    (_)   | \ \        / /      | |   |  ____|  \/  |
   / /_   _ _  __| |\ \  /\  / /__  ___| |_  | |__  | \  / |
  / /| | | | |/ _` | \ \/  \/ / _ \/ __| __| |  __| | |\/| |
 / /_| |_| | | (_| |  \  /\  /  __/\__ \ |_  | |    | |  | |
/_____\__,_|_|\__,_|   \/  \/ \___||___/\__| |_|    |_|  |_|

EOF
echo -e "${GREEN}⎎ Icecast 2 Installation and Configuration${NC}\n"

# Prompt user for input
prompt_user "HOSTNAMES" "localhost" "Hostname(s) separated by space (without http:// or www)" "str"
prompt_user "SOURCEPASS" "hackme" "Source and relay password" "str"
prompt_user "ADMINPASS" "hackme" "Admin password" "str"
prompt_user "LOCATED" "Earth" "Server location (visible on admin pages)" "str"
prompt_user "ADMINMAIL" "root@localhost" "Admin email (for Let's Encrypt)" "email"
prompt_user "PORT" "80" "Port number (1-65535)" "num"

# Validate port number
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo -e "${RED}Error: Invalid port number. Must be between 1 and 65535.${NC}"
  exit 1
fi

prompt_user "SSL" "n" "Enable Let's Encrypt SSL? (y/n)" "y/n"
prompt_user "TIMEZONE" "Europe/Amsterdam" "Server timezone" "str"
prompt_user "DO_UPDATES" "y" "Perform OS updates? (y/n)" "y/n"

# Determine if SSL should be enabled (requires port 80 for Let's Encrypt HTTP-01)
SSL_ENABLED=false
if [ "$SSL" = "y" ] && [ "$PORT" = "80" ]; then
  SSL_ENABLED=true
elif [ "$SSL" = "y" ]; then
  echo -e "${YELLOW}Note: SSL requires port 80 for Let's Encrypt. SSL will be skipped.${NC}"
fi

# Sanitize and validate the entered hostname(s)
IFS=' ' read -r -a HOSTNAMES_ARRAY <<< "$(echo "$HOSTNAMES" | xargs)"
for i in "${!HOSTNAMES_ARRAY[@]}"; do
  domain=$(echo "${HOSTNAMES_ARRAY[i]}" | tr '[:upper:]' '[:lower:]')
  if ! is_valid "$domain" "host" "HOSTNAME"; then
    echo -e "${RED}Error: Invalid hostname format: ${HOSTNAMES_ARRAY[i]}${NC}"
    exit 1
  fi
  HOSTNAMES_ARRAY[i]="$domain"
done
PRIMARY_HOSTNAME="${HOSTNAMES_ARRAY[0]}"

# Validate DNS resolution for hostnames
echo -e "${BLUE}►► Validating DNS resolution...${NC}"
for domain in "${HOSTNAMES_ARRAY[@]}"; do
  if ! getent hosts "$domain" >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Hostname '$domain' does not resolve to an IP address.${NC}"
    echo -e "${YELLOW}This may cause issues, especially with Let's Encrypt SSL certificate acquisition.${NC}"
    prompt_user "CONTINUE_ANYWAY" "n" "Continue anyway? (y/n)" "y/n"
    if [ "$CONTINUE_ANYWAY" != "y" ]; then
      echo -e "${RED}Installation aborted by user.${NC}"
      exit 1
    fi
    break
  fi
done

# Build the domain flags for Certbot as an array
DOMAINS_FLAGS=()
for domain in "${HOSTNAMES_ARRAY[@]}"; do
  DOMAINS_FLAGS+=(-d "$domain")
done

# Set the system timezone
set_timezone "${TIMEZONE}"

# Update the OS if requested
if [ "$DO_UPDATES" = "y" ]; then
  apt_update --silent
fi

if declare -F set_system_hardening_baseline > /dev/null; then
  set_system_hardening_baseline --silent
fi

# Install necessary packages
PACKAGES=(icecast2 libxml2-utils)
if [ "$SSL_ENABLED" = true ]; then
  PACKAGES+=(certbot)
fi
apt_install --silent "${PACKAGES[@]}"

# Backup existing configuration if it exists
if [ -f "$ICECAST_XML" ]; then
  if ! file_backup "$ICECAST_XML"; then
    echo -e "${RED}Failed to backup configuration${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Backed up existing Icecast configuration${NC}"
fi

# Generate the initial icecast.xml configuration
echo -e "${BLUE}►► Creating Icecast configuration...${NC}"
cat << EOF > "$ICECAST_XML"
<icecast>
  <location>$LOCATED</location>
  <admin>$ADMINMAIL</admin>
  <hostname>$PRIMARY_HOSTNAME</hostname>

  <limits>
    <clients>5000</clients>
    <sources>25</sources>
    <burst-size>265536</burst-size>
  </limits>

  <authentication>
    <source-password>$SOURCEPASS</source-password>
    <relay-password>$SOURCEPASS</relay-password>
    <admin-user>admin</admin-user>
    <admin-password>$ADMINPASS</admin-password>
  </authentication>

  <listen-socket>
    <port>$PORT</port>
  </listen-socket>

  <http-headers>
    <header name="Access-Control-Allow-Origin" value="*" />
    <header name="X-Robots-Tag" value="noindex, noarchive" />
  </http-headers>

  <paths>
    <basedir>/usr/share/icecast2</basedir>
    <logdir>/var/log/icecast2</logdir>
    <webroot>${ICECAST_WEBROOT}</webroot>
    <adminroot>/usr/share/icecast2/admin</adminroot>
    <alias source="/" destination="/status.xsl"/>
  </paths>

  <logging>
    <loglevel>1</loglevel>
    <logsize>65536</logsize>
    <logarchive>1</logarchive>
  </logging>
</icecast>
EOF

# Validate the generated XML
echo -e "${BLUE}►► Validating Icecast configuration...${NC}"
if ! xmllint --noout "$ICECAST_XML" 2>&1; then
  echo -e "${RED}Error: Generated icecast.xml is not valid XML. This is a bug in the installer.${NC}"
  exit 1
fi

# Create robots.txt to prevent bots from accessing the server
echo -e "${BLUE}►► Creating robots.txt to block bots...${NC}"
cat << 'ROBOTS_EOF' > "${ICECAST_WEBROOT}/robots.txt"
# Robots.txt for Icecast streaming server
# Prevents bots from consuming bandwidth and indexing

User-agent: *
Disallow: /
ROBOTS_EOF

# Set proper permissions for robots.txt
chown icecast2:icecast "${ICECAST_WEBROOT}/robots.txt"
chmod 644 "${ICECAST_WEBROOT}/robots.txt"

# Set capabilities so that Icecast can listen on ports 80/443
echo -e "${BLUE}►► Setting capabilities for Icecast...${NC}"
setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/icecast2

# Reload and restart the Icecast service
echo -e "${BLUE}►► Starting Icecast service...${NC}"
systemctl enable icecast2
systemctl daemon-reload
systemctl restart icecast2

# Check if Icecast started successfully
if ! systemctl is-active --quiet icecast2; then
  echo -e "${RED}Error: Icecast failed to start. Check logs with: journalctl -u icecast2${NC}"
  exit 1
fi

# SSL configuration
if [ "$SSL_ENABLED" = true ]; then
  echo -e "${BLUE}►► Running Certbot to obtain SSL certificate for domains: ${HOSTNAMES_ARRAY[*]} ${NC}"

  # Create deploy hook script for certificate renewal
  DEPLOY_HOOK_SCRIPT="${LETSENCRYPT_HOOKS_DIR}/icecast2.sh"
  mkdir -p "${LETSENCRYPT_HOOKS_DIR}"
  cat << HOOK_EOF > "$DEPLOY_HOOK_SCRIPT"
#!/bin/bash
set -euo pipefail

CERT_PATH="/etc/letsencrypt/live/${PRIMARY_HOSTNAME}"
ICECAST_PEM="${ICECAST_PEM_PATH}"

# Atomic write via temp file
TEMP_PEM=\$(mktemp)
trap 'rm -f "\$TEMP_PEM"' EXIT

cat "\$CERT_PATH/fullchain.pem" "\$CERT_PATH/privkey.pem" > "\$TEMP_PEM"
chown icecast2:icecast "\$TEMP_PEM"
chmod 600 "\$TEMP_PEM"
mv "\$TEMP_PEM" "\$ICECAST_PEM"

systemctl restart icecast2
HOOK_EOF
  chmod +x "$DEPLOY_HOOK_SCRIPT"

  # Obtain certificate
  if ! certbot --text --agree-tos --email "$ADMINMAIL" --noninteractive --no-eff-email \
    --webroot --webroot-path="${ICECAST_WEBROOT}" \
    "${DOMAINS_FLAGS[@]}" \
    certonly; then
    echo -e "${RED}Certbot failed to obtain certificate${NC}"
    echo -e "${YELLOW}Common causes: DNS not pointing to this server, port 80 blocked, rate limit exceeded${NC}"
    echo -e "${YELLOW}Icecast will continue running on port ${PORT} without SSL${NC}"
    SSL_ENABLED=false
  fi
fi

# Create PEM file and configure SSL in Icecast
if [ "$SSL_ENABLED" = true ] && [ -d "/etc/letsencrypt/live/$PRIMARY_HOSTNAME" ]; then
  # Create combined PEM file using the deploy hook (reuse the same logic)
  "$DEPLOY_HOOK_SCRIPT"

  # Validate the PEM file
  if [ ! -f "${ICECAST_PEM_PATH}" ] || ! openssl x509 -in "${ICECAST_PEM_PATH}" -noout 2>/dev/null; then
    echo -e "${RED}Generated PEM file is invalid or missing${NC}"
    rm -f "${ICECAST_PEM_PATH}"
    SSL_ENABLED=false
  fi
fi

# Update Icecast config with SSL settings
if [ "$SSL_ENABLED" = true ] && [ -f "${ICECAST_PEM_PATH}" ]; then
  sed -i "/<paths>/a \
    \    <ssl-certificate>${ICECAST_PEM_PATH}</ssl-certificate>" "$ICECAST_XML"

  sed -i "/<\/listen-socket>/a \
    <listen-socket>\n\
        <port>443</port>\n\
        <ssl>1</ssl>\n\
    </listen-socket>" "$ICECAST_XML"

  echo -e "${BLUE}►► Validating SSL configuration...${NC}"
  if ! xmllint --noout "$ICECAST_XML" 2>&1; then
    echo -e "${RED}Error: icecast.xml became invalid after adding SSL configuration.${NC}"
    exit 1
  fi

  echo -e "${BLUE}►► Restarting Icecast with SSL support${NC}"
  systemctl restart icecast2
fi

# Display installation summary
echo -e "\n${GREEN}✓ Icecast installation completed!${NC}"
echo -e "${BLUE}►► Installation Summary:${NC}"
echo -e "  Primary hostname: ${CYAN}$PRIMARY_HOSTNAME${NC}"
if [ ${#HOSTNAMES_ARRAY[@]} -gt 1 ]; then
  echo -e "  Additional hostnames: ${CYAN}${HOSTNAMES_ARRAY[*]:1}${NC}"
fi
echo -e "  Admin interface: ${CYAN}http://$PRIMARY_HOSTNAME:$PORT/admin/${NC}"
echo -e "  Admin username: ${CYAN}admin${NC}"
echo -e "  Admin password: ${CYAN}$ADMINPASS${NC}"
echo -e "  Source password: ${CYAN}$SOURCEPASS${NC}"

if [ "$SSL_ENABLED" = true ] && [ -f "${ICECAST_PEM_PATH}" ]; then
  echo -e "\n  ${GREEN}✓ SSL enabled${NC}"
  echo -e "  HTTPS URL: ${CYAN}https://$PRIMARY_HOSTNAME/${NC}"
  echo -e "  Certificate renewal: Automatic via Certbot"
fi

echo -e "\n${YELLOW}Important commands:${NC}"
echo -e "  View logs: ${CYAN}journalctl -u icecast2 -f${NC}"
echo -e "  Restart Icecast: ${CYAN}systemctl restart icecast2${NC}"
echo -e "  Edit configuration: ${CYAN}nano $ICECAST_XML${NC}"
if [ "$SSL_ENABLED" = true ]; then
  echo -e "  Test certificate renewal: ${CYAN}certbot renew --dry-run${NC}"
fi
