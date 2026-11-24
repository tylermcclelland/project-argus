# A minimal Zeek script.
# Run: docker exec zeek zeek /scripts/examples/01-hello.zeek

# Runs once when Zeek starts.
event zeek_init()
	{
	print "Hello from Zeek!";
	}

# Runs once when Zeek finishes.
event zeek_done()
	{
	print "Goodbye!";
	}
