# List of active detections.
# Add a line to enable a detection. Comment a line out with # to disable it.

@load ./port-scan.zeek
@load ./suspicious-user-agent.zeek
@load ./long-dns-query.zeek

@load-sigs ./my-signatures.sig
