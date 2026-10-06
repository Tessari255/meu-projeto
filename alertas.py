"""Contact point local do laboratório. As notificações ficam em docker logs."""
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer


class Receiver(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 65536:
                raise ValueError("Tamanho inválido")
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict):
                raise ValueError("Esperado objeto JSON")
        except (ValueError, json.JSONDecodeError):
            self.send_error(400)
            return
        print(json.dumps({"receivedAt": datetime.now(timezone.utc).isoformat(),
                          "status": payload.get("status"),
                          "alerts": payload.get("alerts", [])}), flush=True)
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"ok")


if __name__ == "__main__":
    # ponytail: laboratório local sem exposição de porta; use um serviço de notificações em produção.
    HTTPServer(("0.0.0.0", 8080), Receiver).serve_forever()
