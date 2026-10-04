#!/usr/bin/env python3
"""Loopback-only test server for a threaded Shandalar Web export.

Not a public production server. Use HTTPS and the same response headers on
your public host; all game files should be served from that same origin.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import tool_banner


class IsolatedHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog=tool_banner.BANNER_HELP)
    tool_banner.add_version_flag(parser, "serve_web.py", __file__)
    parser.add_argument("--directory", type=Path, default=Path.cwd(), help="Extracted game folder")
    parser.add_argument("--port", type=int, default=8000, help="Loopback port (default: 8000)")
    args = parser.parse_args()
    if not args.directory.is_dir() or not (args.directory / "index.html").is_file():
        parser.error("--directory must contain the exported index.html")
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    tool_banner.show(("SHANDALAR WEB",), ("Local threaded-web test server",), __file__)
    handler = partial(IsolatedHandler, directory=str(args.directory.resolve()))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        print(f"Open http://localhost:{args.port}/ (local test server only)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
