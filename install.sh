#!/usr/bin/env bash
# Argus installer. Installs Docker if needed, then sets up and starts Zeek and Suricata.
# Usage: ./install.sh              install to /opt/argus
#        ./install.sh ~/argus      install somewhere else
# Run it again at any time to update an existing install. Your logs and settings are kept.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=$(realpath -m "${1:-/opt/argus}")
MIN_COMPOSE=2.24

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die()  { printf '\nError: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(uname -s)" = Linux ] || die "Argus needs Linux. Live capture uses Docker host networking, which macOS and Windows do not have."

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else
    have sudo || die "sudo is required. Run this script as root instead."
    SUDO=sudo
fi

# ---------------------------------------------------------------- 1. Docker
if ! have docker; then
    say "Docker is not installed. Installing it with Docker's official script..."
    have curl || die "curl is required to install Docker. Install curl, then run this script again."
    curl -fsSL https://get.docker.com | $SUDO sh
fi
if docker --version 2>/dev/null | grep -qi podman; then
    die "'docker' on this computer is Podman. Install Docker Engine instead: https://docs.docker.com/engine/install/"
fi

if have systemctl; then $SUDO systemctl enable --now docker >/dev/null 2>&1 || true; fi

# Use Docker without sudo if the user can. Otherwise use sudo for now and add them to the docker group.
RELOGIN=no
if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
else
    DOCKER=($SUDO docker)
    if [ -n "$SUDO" ] && ! id -nG | grep -qw docker; then
        $SUDO groupadd -f docker
        $SUDO usermod -aG docker "$(id -un)"
        RELOGIN=yes
    fi
fi
"${DOCKER[@]}" info >/dev/null 2>&1 || die "Docker is installed but not running. Start it with: sudo systemctl start docker"

if ! "${DOCKER[@]}" compose version >/dev/null 2>&1; then
    say "Installing the Docker Compose plugin..."
    if have apt-get; then
        $SUDO apt-get update -q
        $SUDO apt-get install -y docker-compose-plugin || $SUDO apt-get install -y docker-compose-v2
    elif have dnf; then
        $SUDO dnf install -y docker-compose-plugin
    else
        die "Install the Docker Compose plugin, then run this script again: https://docs.docker.com/compose/install/linux/"
    fi
fi
COMPOSE_VERSION=$("${DOCKER[@]}" compose version --short | sed 's/^v//')
if [ "$(printf '%s\n%s\n' "$MIN_COMPOSE" "$COMPOSE_VERSION" | sort -V | head -1)" != "$MIN_COMPOSE" ]; then
    die "Docker Compose $COMPOSE_VERSION is too old. Version $MIN_COMPOSE or newer is needed."
fi
echo "Docker $("${DOCKER[@]}" version --format '{{.Server.Version}}') and Compose $COMPOSE_VERSION are ready."

# ---------------------------------------------------------------- 2. Files
if [ "$SRC" != "$DEST" ]; then
    say "Copying Argus to $DEST"
    $SUDO mkdir -p "$DEST"
    $SUDO chown "$(id -u):$(id -g)" "$DEST"
    # Copy everything except logs. Existing logs and settings in $DEST are not touched.
    tar -C "$SRC" --exclude='./zeek/logs/*' --exclude='./suricata/logs/*' \
        --exclude='./suricata/.env' -cf - . | tar -C "$DEST" -xf -
fi
mkdir -p "$DEST/zeek/logs" "$DEST/zeek/pcaps" "$DEST/suricata/logs" "$DEST/suricata/pcaps"
chmod +x "$DEST"/*.sh "$DEST"/zeek/*.sh "$DEST"/zeek/scripts/*.sh "$DEST"/suricata/*.sh "$DEST"/suricata/bin/*.sh

# ---------------------------------------------------------------- 3. Settings
ENV_FILE="$DEST/suricata/.env"
if [ ! -f "$ENV_FILE" ]; then
    IFACE=$(ip route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i+1); exit }}')
    sed "s/^SURICATA_IFACE=.*/SURICATA_IFACE=${IFACE:-}/" "$DEST/suricata/.env.example" > "$ENV_FILE"
    if [ -n "$IFACE" ]; then
        say "Suricata will watch interface $IFACE live (change it in $ENV_FILE)"
    else
        say "No network interface found. Live monitoring is off until you set SURICATA_IFACE in $ENV_FILE"
    fi
fi

# ---------------------------------------------------------------- 4. Start
# Remove old zeek/suricata containers from a previous setup. They hold no data (logs live in folders).
for name in zeek suricata; do
    "${DOCKER[@]}" inspect "$name" >/dev/null 2>&1 || continue
    project=$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")
    if [ "$project" != argus ]; then
        echo "Removing old '$name' container from a previous setup."
        "${DOCKER[@]}" rm -f "$name" >/dev/null
    fi
done

say "Building and starting Zeek and Suricata (the first time takes a few minutes)..."
cd "$DEST"
"${DOCKER[@]}" compose up -d --build

# ---------------------------------------------------------------- Done
say "Argus is installed in $DEST"
cat <<EOF

  Zeek:      cd $DEST/zeek && ./demo.sh
  Suricata:  cd $DEST/suricata && ./test.sh       (analyze the sample pcaps)
             cd $DEST/suricata && ./alerts.sh     (watch live alerts)

  Suricata downloads its rules on first start. Follow along with: docker logs -f suricata
  Read $DEST/README.md for more.
EOF
if [ "$RELOGIN" = yes ]; then
    cat <<EOF

  IMPORTANT: You were added to the 'docker' group. Log out and back in
  (or run 'newgrp docker') before using the scripts above.
EOF
fi
