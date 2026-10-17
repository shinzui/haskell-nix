"""One-request, bounded loopback fixture; never connects to an external service."""
import socket
import sys
from pathlib import Path

if sys.argv[1] == "server":
    with socket.socket() as server:
        server.settimeout(15)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        Path(sys.argv[2]).write_text(str(server.getsockname()[1]))
        connection, _ = server.accept()
        with connection:
            connection.settimeout(5)
            if connection.recv(1024) != b"EP21_LOCAL_SERVICE_REQUEST\n":
                raise RuntimeError("unexpected service request")
            connection.sendall(b"EP21_LOCAL_SERVICE_OK\n")
elif sys.argv[1] == "client":
    port = int(Path(sys.argv[2]).read_text())
    with socket.create_connection(("127.0.0.1", port), timeout=5) as client:
        client.sendall(b"EP21_LOCAL_SERVICE_REQUEST\n")
        response = client.recv(1024)
        if response != b"EP21_LOCAL_SERVICE_OK\n":
            raise RuntimeError("unexpected service response")
        sys.stdout.buffer.write(response)
else:
    raise RuntimeError("expected server/client")
