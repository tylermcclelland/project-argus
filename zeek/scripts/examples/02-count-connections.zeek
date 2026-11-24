# Count connections and print the 5 busiest destination ports.
# Run: docker exec -w /tmp zeek zeek -C -r /pcaps/smallFlows.pcap /scripts/examples/02-count-connections.zeek

global total = 0;
global per_port: table[port] of count;

# Runs when a connection ends.
event connection_state_remove(c: connection)
	{
	total += 1;

	local p = c$id$resp_p;
	if ( p !in per_port )
		per_port[p] = 0;
	per_port[p] += 1;
	}

event zeek_done()
	{
	print fmt("Total connections: %d", total);

	# Print the top 5 ports by repeatedly taking the largest.
	local shown = 0;
	while ( shown < 5 && |per_port| > 0 )
		{
		local best: port = 0/unknown;
		local best_n = 0;
		for ( p, n in per_port )
			if ( n > best_n ) { best = p; best_n = n; }
		print fmt("  %s -> %d connections", best, best_n);
		delete per_port[best];
		shown += 1;
		}
	}
