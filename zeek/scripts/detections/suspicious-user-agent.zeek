##! Alert on HTTP requests sent by hacking or automation tools.

module SuspiciousUA;

export {
	redef enum Notice::Type += { Suspicious_User_Agent };

	# Tool names to match. The /i flag ignores case.
	const bad_agents = /(nmap|sqlmap|nikto|masscan|curl|wget|python-requests)/i &redef;
}

event http_header(c: connection, is_orig: bool, original_name: string, name: string, value: string)
	{
	# is_orig is true for headers sent by the client.
	if ( is_orig && name == "USER-AGENT" && bad_agents in value )
		NOTICE([$note=Suspicious_User_Agent,
		        $conn=c,
		        $msg=fmt("Tool-like User-Agent seen: %s", value),
		        $sub=value,
		        $identifier=cat(c$id$orig_h, value)]);
	}
