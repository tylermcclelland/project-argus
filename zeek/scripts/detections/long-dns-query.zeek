##! Alert on very long DNS names, a common sign of DNS tunneling.

module LongDNS;

export {
	redef enum Notice::Type += { Long_DNS_Query };

	# Maximum normal name length.
	const max_length = 60 &redef;
}

event dns_request(c: connection, msg: dns_msg, query: string, qtype: count, qclass: count)
	{
	if ( |query| > max_length )
		NOTICE([$note=Long_DNS_Query,
		        $conn=c,
		        $msg=fmt("DNS name is %d characters long: %s", |query|, query),
		        $identifier=query]);
	}
