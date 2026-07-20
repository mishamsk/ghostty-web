# @ghostty-web/demo

Cross-platform demo server for [ghostty-web](https://github.com/coder/ghostty-web) terminal emulator.

## Quick Start

```bash
npx @ghostty-web/demo@next
```

This starts a local web server with a fully functional terminal connected to your shell.
Works on **Linux** and **macOS** (no Windows support yet).

## What it does

- Starts an HTTP server on `127.0.0.1:8080` by default (`PORT` and `HOST` are configurable)
- Serves WebSocket PTY on the same port at `/ws` endpoint
- Protects `/ws` with a per-run same-origin token from `/api/token`
- Rejects cross-origin WebSocket handshakes
- Opens a real shell session (bash, zsh, etc.)
- Provides full PTY support (colors, cursor positioning, resize, etc.)

## Usage

```bash
# Default (port 8080)
npx @ghostty-web/demo@next

# Custom port
PORT=3000 npx @ghostty-web/demo@next

# Explicit bind host for intentional non-default access
HOST=192.0.2.10 GHOSTTY_ALLOWED_HOSTS=demo.example npx @ghostty-web/demo@next
```

Then open http://127.0.0.1:8080 in your browser.

## Running a checkout in the background

The repository includes `just` recipes for installing the demo dependencies and
running this checkout as a detached local process:

```bash
cp .env.example .env
# Edit .env for the bind address, port, and allowed browser-visible hosts.
just start
just status
just logs
just stop
```

Runtime state and logs are written under
`~/.local/state/ghostty-web-demo`. On macOS the detached process is managed by
`launchd`; other platforms use `nohup` (and `setsid` when available). The local
`.env` file is ignored by Git.

## Bind host and proxy configuration

The demo binds to `127.0.0.1` by default and only allows loopback hostnames (`localhost`, `127.0.0.1`, and `::1`) unless configured otherwise. Set `HOST=<host>` to change the bind address. If you serve the demo through another hostname, or bind to a wildcard such as `HOST=0.0.0.0`, add the browser-visible hostnames with `GHOSTTY_ALLOWED_HOSTS=host1,host2`.

The browser client fetches `/api/token` from the same origin before opening `/ws`, and the server rejects `/ws` when the token is missing, the `Host` is not allowed, or the WebSocket `Origin` does not match the request host. Do not set permissive CORS in front of `/api/token`.

### Example with nginx

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## Security Warning

⚠️ **This server provides full shell access.**

Only use for local development and demos. Keep the default loopback bind unless you intentionally need remote access and have configured `HOST` and `GHOSTTY_ALLOWED_HOSTS` for the exact hostnames you trust.
