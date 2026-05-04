FROM ubuntu:24.04

RUN apt-get update 
RUN apt-get install -y --no-install-recommends python3 
RUN rm -rf /var/lib/apt/lists/*

EXPOSE 6001

CMD ["python3", "-c", "\
import http.server, socketserver\n\
class H(http.server.BaseHTTPRequestHandler):\n\
    def do_GET(self):\n\
        body = b'Hello World\\n'\n\
        self.send_response(200)\n\
        self.send_header('Content-Length', len(body))\n\
        self.end_headers()\n\
        self.wfile.write(body)\n\
    def log_message(self, fmt, *args):\n\
        import sys; print(fmt % args, flush=True, file=sys.stderr)\n\
with socketserver.TCPServer(('', 6001), H) as s:\n\
    s.serve_forever()\n\
"]
