# Official Zeek image (pinned so results stay the same between installs) plus a few networking tools.
FROM zeek/zeek:9.0.1

# tcpdump  - record traffic to .pcap files
# nmap     - scan ports
# curl     - make web requests
# iproute2 - list network interfaces (ip command)
RUN apt-get update \
 && apt-get install -y --no-install-recommends tcpdump nmap curl iproute2 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /logs
