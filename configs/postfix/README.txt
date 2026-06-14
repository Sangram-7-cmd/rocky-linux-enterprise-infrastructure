main.cf.server1  →  Server 1 config (handles urban.com)
main.cf.server2  →  Server 2 config (handles rural.com)

Mail flow:
Client → Server 1 (urban.com) → DNS MX lookup → Server 2 (rural.com)
