# A server that never stops sending.
#
# Answers one request with a chunked body and no Content-Length, then writes
# zeros until the client hangs up. That is the response --max-filesize cannot
# see coming, so it is the one the download cap has to survive. Writes its port
# to argv[1] and, when the client disconnects, the number of body bytes it
# managed to push to argv[2].
import socket, sys, os

port_file, count_file = sys.argv[1], sys.argv[2]
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 0))
srv.listen(1)
with open(port_file, "w") as f:
    f.write(str(srv.getsockname()[1]))

conn, _ = srv.accept()
try:
    while b"\r\n\r\n" not in conn.recv(65536):
        pass
except OSError:
    pass
conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
             b"Transfer-Encoding: chunked\r\n\r\n")

chunk = b"0" * 65536
framed = b"%x\r\n" % len(chunk) + chunk + b"\r\n"
sent = 0
try:
    # Far more than any cap under test; if the client never hangs up, the test
    # should fail on the byte count rather than run forever.
    while sent < 512 * 1024 * 1024:
        conn.sendall(framed)
        sent += len(chunk)
except OSError:
    pass
finally:
    with open(count_file, "w") as f:
        f.write(str(sent))
    try:
        conn.close()
    except OSError:
        pass
    srv.close()
