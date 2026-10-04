"""The local Web test server sends isolation headers on files and failures."""
from functools import partial
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
import tempfile
import threading
import unittest

from serve_web import IsolatedHandler


class WebServerTest(unittest.TestCase):
    def test_headers_on_page_assets_and_errors(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "index.html").write_text("<title>Test</title>")
            (root / "index.wasm").write_bytes(b"wasm")
            server = ThreadingHTTPServer(("127.0.0.1", 0), partial(IsolatedHandler, directory=temp))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                for path, status in (("/", 200), ("/index.wasm", 200), ("/missing", 404)):
                    connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                    try:
                        connection.request("GET", path)
                        response = connection.getresponse()
                        self.assertEqual(response.status, status)
                        self.assertEqual(response.getheader("Cross-Origin-Opener-Policy"), "same-origin")
                        self.assertEqual(response.getheader("Cross-Origin-Embedder-Policy"), "require-corp")
                        if path.endswith(".wasm"):
                            self.assertEqual(response.getheader("Content-Type"), "application/wasm")
                        response.read()
                    finally:
                        connection.close()
            finally:
                server.shutdown()
                thread.join(timeout=5)
                server.server_close()
