# Zeek Lab

A ready-to-run [Zeek](https://zeek.org) network monitoring lab in Docker.

Zeek watches network traffic and writes readable logs about it: who connected to whom, which websites were visited, which domains were looked up, and more. You can also write your own rules that raise alerts.

## Requirements

- **Linux** (live capture and the demo need Docker host networking; on macOS or Windows only pcap analysis works)
- **Docker** with the Compose plugin
- About **1 GB** of free disk space

## Setup

Install with the `install.sh` script in the main folder. It installs Docker if needed and starts Zeek. Then download the sample pcaps:

```bash
./download-samples.sh            # download sample pcap files (about 360 MB)
```

To run only Zeek without the installer: `docker compose up -d --build` in this folder.

## Run the demo

```bash
./demo.sh
```

The demo creates fake attack traffic on your loopback interface (`127.0.0.1`), runs Zeek on it, and prints a summary. All traffic stays on your computer.

| Simulated attack | Alert |
|---|---|
| Port scan with nmap | `PortScan::Port_Scan` |
| Request for `/etc/passwd` | `Signatures::Sensitive_Signature` |
| Directory traversal (`../../`) | `Signatures::Sensitive_Signature` |
| Password sent in clear text | `Signatures::Sensitive_Signature` |
| Requests from `sqlmap` and `curl` | `SuspiciousUA::Suspicious_User_Agent` |
| DNS tunneling (very long domain name) | `LongDNS::Long_DNS_Query` |

## Commands

| Command | What it does |
|---|---|
| `./demo.sh` | Run the demo |
| `./analyze.sh pcaps/FILE.pcap` | Analyze a pcap. Logs go to `logs/FILE/` |
| `./summary.sh logs/FILE` | Summarize the results |
| `./view.sh logs/FILE/conn.log` | Show a log as a table (`q` to quit, `/` to search) |
| `./live.sh eth0` | Watch an interface live (Ctrl+C to stop). Run without a name to list interfaces |
| `docker compose down` | Stop the container |

To analyze your own traffic, put a `.pcap` file in `pcaps/` and run `./analyze.sh` on it. Free pcap files are available at [Netresec](https://www.netresec.com/?page=PcapFiles) and [Wireshark](https://wiki.wireshark.org/SampleCaptures).

## Reading the logs

1. Run `./summary.sh` for an overview.
2. Read all of `notice.log` for alerts and note any suspicious IPs.
3. Search `conn.log` for those IPs to see what else they did.
4. Check `dns.log`, `http.log`, and `ssl.log` for details.

Each connection has an ID in the `uid` column that appears in every related log. Run `grep <uid> logs/FILE/*.log` to follow one connection across all logs.

| Log | Contents |
|---|---|
| `notice.log` | Alerts |
| `conn.log` | Every connection |
| `dns.log` | Domain lookups |
| `http.log` | Unencrypted web requests |
| `ssl.log` | HTTPS connections (site name only) |
| `files.log` | Files sent over the network |
| `weird.log` | Unusual traffic (usually harmless) |

**Columns:** `id.orig_h` is the client, `id.resp_h` is the server, and `_p` is the port. `-` means no value.

**Connection states:** `SF` is a normal connection. `S0` (no reply) and `REJ` (rejected) are failed attempts. Many of these suggest a scan.

> The summary is a starting point, not a full report. It shows the most common items, while attacks are often rare. It also only shows alerts that a rule caught. No alerts does not mean no attacks.

## Live capture

```bash
./live.sh eth0                                                # watch eth0 with Zeek
docker exec zeek tcpdump -i eth0 -c 500 -w /pcaps/cap.pcap    # record a pcap
docker exec zeek nmap -sT 127.0.0.1                           # scan with nmap
```

Only scan computers you own or have permission to scan.

## Write your own detections

Detections live in `scripts/detections/`. Use a **script** (`.zeek`) for logic such as counting. Use a **signature** (`.sig`) to match byte patterns.

Zeek scripts are event-driven: Zeek fires an event when something happens, and your code runs. Common events include `new_connection`, `dns_request`, `http_request`, and `ssh_auth_failed` ([full list](https://docs.zeek.org/en/master/scripts/base/bif/event.bif.zeek.html)). See `scripts/examples/` for simple scripts to start from.

### Example: alert on Telnet

**1.** Create `scripts/detections/telnet.zeek`:

```zeek
module Telnet;

export {
	redef enum Notice::Type += { Telnet_Used };
}

event new_connection(c: connection)
	{
	if ( c$id$resp_p == 23/tcp )
		NOTICE([$note=Telnet_Used, $conn=c,
		        $msg=fmt("%s connected to Telnet on %s", c$id$orig_h, c$id$resp_h)]);
	}
```

**2.** Add `@load ./telnet.zeek` to `scripts/detections/__load__.zeek`.

**3.** Check for errors. No output means no errors.

```bash
docker exec zeek zeek -a local
```

**4.** Create test traffic and analyze it:

```bash
docker exec -d zeek tcpdump -i lo -w /pcaps/telnet-test.pcap port 23
docker exec zeek sh -c "curl -s --max-time 2 telnet://127.0.0.1:23; true"
docker exec zeek pkill tcpdump
./analyze.sh pcaps/telnet-test.pcap
```

You should see a `Telnet::Telnet_Used` alert.

### Example: signature

Add this to `scripts/detections/my-signatures.sig`. All conditions must match.

```
signature web-etc-passwd {
  ip-proto == tcp
  http-request /.*\/etc\/passwd/
  event "HTTP request for /etc/passwd"
}
```

See the [signature documentation](https://docs.zeek.org/en/master/frameworks/signatures.html) for all conditions.

### Reducing false alerts

If a rule fires on normal traffic, raise its threshold in `scripts/local.zeek` (for example, `redef LongDNS::max_length = 80;`) or skip known-good values in the script.

## Limitations

- Zeek detects attacks but does not block them.
- Zeek cannot see inside encrypted traffic.
- On a switched network, you only see your own computer's traffic. Use a switch mirror (SPAN) port to see other devices.
- The included rules are simple examples and are easy to evade.

## Troubleshooting

| Problem | Solution |
|---|---|
| `No such container: zeek` | Run `docker compose up -d` |
| Docker `permission denied` | Run `sudo usermod -aG docker $USER`, then log out and back in |
| Script `permission denied` | Run `chmod +x *.sh scripts/*.sh` |
| `syntax error` in a `.zeek` file | Check the line number. It's usually a missing `;` or `}` |
| Can't delete files in `logs/` | Run `docker exec zeek chown -R $(id -u):$(id -g) /logs /pcaps` |

## Learn more

- [Try Zeek in your browser](https://try.zeek.org)
- [Zeek documentation](https://docs.zeek.org)
