# DeepSeek Harness on your phone (via Tailscale)

Use the **DeepSeek Harness GUI from your phone** while the work stays on your laptop.

- 🔒 **Private & encrypted** — your laptop is *not* exposed to the internet. Only devices signed in to **your** Tailscale account can reach it.
- ⚡ **One command** to set up — no manual port forwarding, no firewall changes.
- 📱 Works from iPhone and Android in any browser.

---

## Setup (laptop) — one command

> Requirements: Windows 10/11, and you already run the harness with `dsh web`.

1. Open **PowerShell** (press `Win`, type `powershell`, press Enter).
2. Paste this and press **Enter**:

```powershell
irm https://raw.githubusercontent.com/1aifanatic/deepseek-harness-phone-access/main/setup-phone-access.ps1 | iex
```

3. Follow the prompts. The script will:
   - install **Tailscale** automatically if you don't have it (and sign you in if needed),
   - open a browser page where you click **one button** to enable *Serve* (only the first time),
   - point your private tailnet address at the harness on port 3080,
   - restart `dsh web` with `--trusted-host` (your sessions are saved),
   - print your **phone URL**.
4. When it says **DONE**, refresh `http://127.0.0.1:3080` on the laptop.

---

## On your phone (once)

1. Install the free **Tailscale** app from the App Store (iPhone) or Play Store (Android).
2. Sign in with the **same account** as your laptop.
3. Open the `https://….ts.net` URL the script printed — you're in.

---

## What works from the phone

Everything you do in the chat surface:

- conversations, tools, file editing, background jobs, goals, session history

## What stays laptop-only (by design)

The harness deliberately pins these to the laptop (they return `403` from the phone):

- folder picker, opening files in native apps
- settings, credentials, agent presets
- model discovery

Use those on the laptop — everything else works on the phone.

---

## Daily use

- Keep the laptop awake (plugged in / sleep disabled).
- Start the harness with the command the script printed:

```powershell
dsh web --trusted-host <your-laptop>.<your-tailnet>.ts.net
```

- The Tailscale app on the phone should stay signed in.

## Undo (remove phone access)

```powershell
tailscale serve reset
```

Then start the harness as before with a plain `dsh web`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Script says *"Serve is not enabled"* | Click the enable button in the browser page the script opens, then press Enter. |
| Phone can't reach the URL | Same Tailscale account on both devices, Tailscale app running, laptop awake. |
| Folder picker / settings give 403 on the phone | By design — do those on the laptop. |
| Tailscale didn't install | Install from https://tailscale.com/download and re-run the script. |
| Harness not responding after setup | Refresh the laptop browser; or run `dsh web --trusted-host <…ts.net>` in a terminal. |
| Script doesn't apply to macOS | The one-liner is Windows/PowerShell. On macOS, run the equivalent manually: `tailscale serve --bg 3080` and start `dsh web --trusted-host $(tailscale status --json | …)` — or open an issue and I'll add a shell version. |

---

## How it works (short version)

- `dsh web` binds to `127.0.0.1:3080` only, and deliberately refuses `0.0.0.0` (it would expose remote code execution to your whole network).
- `tailscale serve` gives the laptop a private `https://<name>.ts.net` address that forwards to `127.0.0.1:3080` — reachable only by your devices.
- `--trusted-host <name>.ts.net` tells the harness's `/api` trust fence to accept that address. The fence is a DNS-rebinding / cross-site defense — *not* authentication — which is exactly why Tailscale (your private network) is the safe way to do this, and why the harness keeps native dialogs, settings and credentials loopback-only.

---

## License

MIT — see [LICENSE](LICENSE).
