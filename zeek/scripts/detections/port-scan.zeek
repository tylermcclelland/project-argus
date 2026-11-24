##! Alert when one IP connects to many different ports within one minute.

module PortScan;

export {
	redef enum Notice::Type += { Port_Scan };

	# Number of different ports that triggers the alert.
	const threshold = 20 &redef;
}

# Ports tried by each source IP. Entries expire after one minute.
global ports_seen: table[addr] of set[port] &create_expire=1min;

event new_connection(c: connection)
	{
	local src = c$id$orig_h;

	if ( src !in ports_seen )
		ports_seen[src] = set();

	add ports_seen[src][c$id$resp_p];

	# Use == so the alert fires only once per IP.
	if ( |ports_seen[src]| == threshold )
		NOTICE([$note=Port_Scan,
		        $conn=c,
		        $msg=fmt("%s tried %d different ports within 1 minute", src, threshold),
		        $identifier=cat(src)]);
	}
