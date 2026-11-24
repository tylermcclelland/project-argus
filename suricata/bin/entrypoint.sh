#!/bin/bash
# Container start-up: download rules on first start, then watch $SURICATA_IFACE live.
# If live monitoring is off or fails, the container stays up so pcap analysis still works.

# Copy the image's default config files into place (same as the image's own entrypoint).
for src in /etc/suricata.dist/*; do
    dst="/etc/suricata/$(basename "$src")"
    [ -e "$dst" ] || cp -a "$src" "$dst"
done

if [ ! -s /var/lib/suricata/rules/suricata.rules ]; then
    echo "First start: downloading rules (this can take a minute)..."
    suricata-update --local /custom-rules || echo "Warning: rule download failed. Run ./update-rules.sh later."
fi

idle() {
    echo "Pcap analysis still works. Live monitoring is off."
    trap 'exit 0' TERM INT
    sleep infinity &
    wait
}

IFACE=${SURICATA_IFACE:-}
if [ -z "$IFACE" ]; then
    echo "SURICATA_IFACE is not set in suricata/.env."
    idle
fi
if [ ! -e "/sys/class/net/$IFACE" ]; then
    echo "Interface '$IFACE' does not exist. Set SURICATA_IFACE in suricata/.env, then run: docker restart suricata"
    idle
fi

ARGS=()
[ -n "${HOME_NET:-}" ] && ARGS+=(--set "vars.address-groups.HOME_NET=$HOME_NET")

mkdir -p /logs/live
echo "Watching $IFACE. Alerts go to logs/live/fast.log."
suricata -i "$IFACE" -l /logs/live "${ARGS[@]}" &
pid=$!
trap 'kill -TERM $pid 2>/dev/null; wait $pid; exit 0' TERM INT
wait $pid
echo "Suricata stopped (exit code $?). See logs/live/suricata.log."
idle
