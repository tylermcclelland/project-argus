# Zeek signatures: alert when traffic matches a byte pattern.
# All conditions in a signature must match.

# Request for the Linux password file.
signature web-etc-passwd {
  ip-proto == tcp
  http-request /.*\/etc\/passwd/
  event "HTTP request for /etc/passwd"
}

# Directory traversal (../../).
signature web-directory-traversal {
  ip-proto == tcp
  http-request /.*\.\.\/\.\.\//
  event "HTTP directory traversal attempt (../../)"
}

# Password sent in clear text by the client.
signature cleartext-password-word {
  ip-proto == tcp
  payload /.*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]=/
  tcp-state originator
  event "Clear-text 'password=' seen"
}
