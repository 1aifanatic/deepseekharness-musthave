---
name: quick-tunnel
description: Instantly expose any local port (such as a Next.js/Vite dev server or the DSH Web GUI on port 3080) to a public HTTPS URL via zero-login Cloudflare Quick Tunnels. Use when the user asks to "share my app", "give me a public URL", "expose port 3000", "test on my phone", or "share this port".
---

# Quick Tunnel (`/share-port`)

Instantly generate a free, secure, temporary public HTTPS URL (`https://*.trycloudflare.com`) pointing to any local port on your machine without account signup or port forwarding.

## When to Use

- Sharing a local web app or prototype with a teammate or client.
- Testing responsive web apps directly on a mobile phone or external device.
- Exposing the DeepSeek Harness Web GUI (`http://127.0.0.1:3080`) for quick remote access.

## Commands

### 1. Share a Port (e.g. 3000)
```powershell
pwsh -File "<skill-dir>/tunnel.ps1" 3000
```

### 2. Share DSH Web GUI (Port 3080)
```powershell
pwsh -File "<skill-dir>/tunnel.ps1" 3080
```

### 3. Stop All Running Tunnels
```powershell
pwsh -File "<skill-dir>/tunnel.ps1" -KillAll
```
