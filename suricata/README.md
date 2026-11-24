# Suricata

[Suricata](https://suricata.io) is an intrusion detection system (IDS). It checks network traffic against rules that describe known attacks and writes an alert when one matches. It uses the free [Emerging Threats Open](https://rules.emergingthreats.net) ruleset plus your own rules.

Install it with the `install.sh` script in the main folder. To run only Suricata: `docker compose up -d --build` in this folder.

## Commands

| Command | What it does |
|---|---|
| `./test.sh` | Analyze every pcap in `pcaps/` and print the alert count for each |
| `./analyze.sh pcaps/FILE.pcap` | Analyze one pcap (or a folder of pcaps). Logs go to `logs/FILE/` |
| `./alerts.sh` | Watch live alerts (Ctrl+C to stop) |
| `./update-rules.sh` | Download the latest rules, add yours, and restart |
| `./clear-logs.sh` | Delete live logs (`--all` also deletes pcap results) |

## Live monitoring

Suricata watches the interface set in `.env` all the time, including after a reboot. Live logs go to `logs/live/`.

```bash
SURICATA_IFACE=wlan0          # interface to watch (list them with: ip -br link)
HOME_NET=[192.168.1.0/24]     # optional: your own network
```

After editing `.env`, run `docker restart suricata`. Leave `SURICATA_IFACE` empty to turn live monitoring off.

Live logs grow without limit on a busy network. Run `./clear-logs.sh` now and then.

## Logs

| Log | Contents |
|---|---|
| `fast.log` | Alerts, one per line |
| `eve.json` | Everything (alerts, flows, DNS, HTTP, TLS, ...) as JSON, one event per line |
| `stats.log` | Performance counters. Check `capture.kernel_drops` when watching live |
| `suricata.log` | Suricata's own messages and errors |

To read alerts from `eve.json` with [jq](https://jqlang.org): `jq 'select(.event_type=="alert") | .alert.signature' logs/FILE/eve.json`

## Write your own rules

Add rules to `rules/local.rules`, then run `./update-rules.sh`. The file has examples. See the [rule documentation](https://docs.suricata.io/en/latest/rules/intro.html).

## Notes

- Suricata runs in **IDS mode**: it alerts but does not block. The old IPS (blocking) setup is in `legacy-pi-scripts/` and is not part of the Docker setup.
- Pcaps from a Wi-Fi monitor interface (radiotap, such as the ones in `pcaps/arp_pcaps/`) are not supported and show as `failed` in `./test.sh`.
- Alert counts depend on the rules version. Rules are downloaded on first start and only change when you run `./update-rules.sh`.
- `legacy-pi-scripts/` holds the old scripts that installed Suricata directly on a Raspberry Pi. They are no longer needed.
