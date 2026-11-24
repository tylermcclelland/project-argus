# Argus

Two network security tools, ready to run in Docker:

- **[Zeek](zeek/README.md)** writes detailed logs of all network activity (connections, DNS, web requests, ...) and raises alerts from custom scripts.
- **[Suricata](suricata/README.md)** checks traffic against tens of thousands of known attack signatures and raises alerts.

Both can analyze saved `.pcap` files or watch a network interface live.

## Install

Requires **Linux** (Debian, Ubuntu, Raspberry Pi OS, Fedora, ...) and about **2 GB** of disk space.

```bash
./install.sh
```

The installer:

1. Installs Docker and Docker Compose if they are missing.
2. Copies Argus to **`/opt/argus`** (pass another folder to change it: `./install.sh ~/argus`).
3. Picks your main network interface for Suricata to watch live.
4. Builds and starts both tools. They start again automatically after a reboot.

Run it again at any time to update an install. Logs and settings are kept.

## Quick start

```bash
cd /opt/argus/zeek && ./demo.sh          # Zeek: create test attacks and detect them
cd /opt/argus/suricata && ./test.sh      # Suricata: analyze the sample pcaps
cd /opt/argus/suricata && ./alerts.sh    # Suricata: watch live alerts
```

## Manage

| Command (run in `/opt/argus`) | What it does |
|---|---|
| `docker compose ps` | Show whether both tools are running |
| `docker compose down` | Stop both |
| `docker compose up -d --build` | Start both (and rebuild after changes) |
| `docker logs suricata` | Show Suricata's start-up messages |

## Uninstall

```bash
cd /opt/argus && docker compose down --rmi local --volumes
sudo rm -rf /opt/argus
```

Only use these tools on networks you own or have permission to monitor.
