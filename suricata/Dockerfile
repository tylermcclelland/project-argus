# Official Suricata image (maintained by a Suricata core developer), pinned so
# alert counts stay the same between installs. Works on x86 and ARM (Raspberry Pi).
FROM jasonish/suricata:8.0.8

COPY bin/entrypoint.sh /usr/local/bin/argus-entrypoint
RUN chmod +x /usr/local/bin/argus-entrypoint

ENTRYPOINT ["/usr/local/bin/argus-entrypoint"]
