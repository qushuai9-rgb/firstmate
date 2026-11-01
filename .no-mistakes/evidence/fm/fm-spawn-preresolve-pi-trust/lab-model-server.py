#!/usr/bin/env python3
"""A disposable OpenAI-compatible chat endpoint for lab-driving the real `pi` CLI.

Serves /v1/models and /v1/chat/completions (streaming and non-streaming) with a
canned assistant reply, so a real pi turn can complete end to end without any
operator credential. Binds 127.0.0.1 on an ephemeral port and prints
"READY <port>" on stdout. Usage: lab-model-server.py [reply-text]
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLY = sys.argv[1] if len(sys.argv) > 1 else "LAB_WORKER_TURN_OK"
MODEL = "lab-model"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("REQ " + (fmt % args) + "\n")
        sys.stderr.flush()

    def do_GET(self):
        if self.path.rstrip("/").endswith("/models"):
            body = json.dumps(
                {
                    "object": "list",
                    "data": [{"id": MODEL, "object": "model", "owned_by": "lab"}],
                }
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            payload = {}
        sys.stderr.write("BODY keys=" + json.dumps({k: v for k, v in payload.items() if k != "messages"})[:600] + "\n"); sys.stderr.flush()
        stream = bool(payload.get("stream"))
        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "close")
            self.close_connection = True
            self.end_headers()
            for piece in (REPLY, ""):
                chunk = {
                    "id": "chatcmpl-lab",
                    "object": "chat.completion.chunk",
                    "model": MODEL,
                    "choices": [
                        {
                            "index": 0,
                            "delta": {"role": "assistant", "content": piece} if piece else {},
                            "finish_reason": None if piece else "stop",
                        }
                    ],
                }
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
            usage = {
                "id": "chatcmpl-lab",
                "object": "chat.completion.chunk",
                "model": MODEL,
                "choices": [],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            }
            self.wfile.write(f"data: {json.dumps(usage)}\n\n".encode())
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
            return
        body = json.dumps(
            {
                "id": "chatcmpl-lab",
                "object": "chat.completion",
                "model": MODEL,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": REPLY},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            }
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(f"READY {server.server_address[1]}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
