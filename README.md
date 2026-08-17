# 🚀 DeepSeek Harness Must-Have Suite

> **Essential plugins, tools, and skills for DeepSeek Harness — plus cross-compatibility with Claude Code, OpenAI Codex, Cursor, and Cline.**

[![DeepSeek Harness](https://img.shields.io/badge/DeepSeek%20Harness-Must--Have%20Suite-purple?style=flat-square)](https://github.com/1aifanatic/deepseekharness-musthave)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Platform: Windows%20%7C%20macOS%20%7C%20Linux](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue?style=flat-square)](https://github.com/1aifanatic/deepseekharness-musthave)

---

## ✨ The Must-Have Collection

| Component | What it does | Supported Harnesses |
|---|---|---|
| 🤖 **[External CLI Router](./external-cli-router)** | Use **Claude Code CLI** & **OpenAI Codex CLI** as selectable models, delegation tools, and subagents inside DSH. | DeepSeek Harness |
| 📱 **[Phone Access Setup](./phone-access-setup)** | Use the **DSH Web GUI from your phone** safely and privately over your Tailscale tailnet. | DeepSeek Harness |
| 🔔 **[Bell Notifier](./bell-notifier)** | Instant push notification to your phone via free [ntfy.sh](https://ntfy.sh), Discord, Telegram, or audio chime when long agent jobs finish. | DSH, Claude Code, Codex, Cursor |
| 📋 **[Clipboard Context](./clipboard-context)** | Read, clean, and sanitize error logs, snippets, or screenshots directly from your OS clipboard into the agent. | DSH, Claude Code, Codex, Cursor |
| ⏱️ **[Git Checkpoint](./git-checkpoint)** | 1-second instant git snapshot of all staged + unstaged files with single-command rollback before risky refactors. | DSH, Claude Code, Codex, Cursor |
| 🚀 **[Quick Tunnel](./quick-tunnel)** | Instant free temporary HTTPS URL (`https://*.trycloudflare.com`) pointing to any local port or your DSH GUI (zero signup). | DSH, Claude Code, Codex, Cursor |
| ⚡ **[Gemini CLI Router](./gemini-cli-router)** | Ultra-fast **Google Gemini 2.0 Flash / Pro** delegation tool and dynamic preset for fast subtasks & second opinions. | DSH, Claude Code, Codex, Cursor |

---

## ⚡ 30-Second Quick Install

### Install All Skills & Routers

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/scripts/setup.ps1 | iex
```

**macOS / Linux (Bash):**
```bash
curl -fsSL https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/scripts/setup.sh | bash
```

---

## 🛠️ Deep Dive: The 7 Tools

### 1. 🤖 `external-cli-router`
Use Claude Code CLI and Codex CLI inside DeepSeek Harness:
- **Model Picker**: Select Claude Sonnet 4, Opus 4, Haiku, GPT-5, o3, or o4-mini with full Thinking Effort control (Low/Medium/High).
- **Delegation Tools**: Call `delegate_to_claude` or `delegate_to_codex` for one-shot prompts without changing your main session model.
- **Install One-Liner**:
  ```powershell
  irm https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/external-cli-router/setup.ps1 | iex
  ```
- *See full documentation in [external-cli-router/README.md](./external-cli-router/README.md).*

---

### 2. 📱 `phone-access-setup`
Access DeepSeek Harness GUI from your phone securely:
- Zero manual port forwarding, no firewall changes.
- Uses your private encrypted Tailscale network.
- **Install One-Liner**:
  ```powershell
  irm https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/phone-access-setup/setup-phone-access.ps1 | iex
  ```
- *See full documentation in [phone-access-setup/README.md](./phone-access-setup/README.md).*

---

### 3. 🔔 `bell-notifier` (`ding`)
Never sit staring at a terminal waiting for an agent or test suite to complete:
- **Free Mobile Push**: Subscribe to a private topic on the free [ntfy app](https://ntfy.sh) (iOS / Android) and set `$env:AGENT_NOTIFY_TOPIC = "my-secret-topic"`.
- **Discord / Telegram**: Store webhook or bot token in `~/.config/agent-notify.json`.
- **System Sound**: Fallback double audio chime.
- **Trigger**: Ask your agent *"Ping my phone when done"*, *"Send a ding"*, or run:
  ```powershell
  pwsh bell-notifier/notify.ps1 -Message "All 54 tests passed!" -Title "Build Green"
  ```

---

### 4. 📋 `clipboard-context` (`/clip`)
Skip the copy-paste ceremony for 500-line tracebacks and terminal outputs:
- Strips ANSI color codes and shell prompt junk automatically.
- Detects copied screenshots and saves them for vision-capable agents.
- **Trigger**: Ask your agent *"Look at what I just copied"*, *"Check my clipboard"*, or run:
  ```powershell
  pwsh clipboard-context/grab-clip.ps1
  ```

---

### 5. ⏱️ `git-checkpoint` (`/checkpoint` & `/rollback`)
Zero-overhead insurance before risky multi-file agent edits:
- Saves dirty staged and unstaged state via lightweight git refs without creating branches or altering history.
- **Commands**:
  ```powershell
  # 1. Take snapshot before refactoring
  pwsh git-checkpoint/checkpoint.ps1 save "before-auth-refactor"

  # 2. Instant 1-second rollback if tests fail
  pwsh git-checkpoint/checkpoint.ps1 rollback

  # 3. List checkpoints
  pwsh git-checkpoint/checkpoint.ps1 list
  ```

---

### 6. 🚀 `quick-tunnel` (`/share-port`)
Instantly expose any local port with a free public HTTPS URL:
- Built on Cloudflare Quick Tunnels — no account creation, no domain required.
- **Commands**:
  ```powershell
  # Share a local Next.js/Vite app (port 3000)
  pwsh quick-tunnel/tunnel.ps1 3000

  # Share DeepSeek Harness Web GUI (port 3080)
  pwsh quick-tunnel/tunnel.ps1 3080

  # Stop tunnels
  pwsh quick-tunnel/tunnel.ps1 -KillAll
  ```

---

### 7. ⚡ `gemini-cli-router` (`delegate-to-gemini`)
Fast delegation to Google Gemini 2.0 Flash / 2.5 Pro:
- Sub-second second opinions and massive 1M+ token context analysis.
- Includes both a standalone CLI script and a DSH Dynamic Cordis plugin.
- **Commands**:
  ```powershell
  $env:GEMINI_API_KEY = "AIzaSy..."
  pwsh gemini-cli-router/gemini-run.ps1 -Prompt "Review this logic for race conditions" -Model "gemini-2.0-flash"
  ```

---

## 🎯 Universal Agent Compatibility

All skills are structured according to standard Agent Skill specifications (`SKILL.md`) and install into `~/.agents/skills` and `~/.claude/skills`:

| Feature | DeepSeek Harness | Claude Code | OpenAI Codex | Cursor / Cline | OpenClaw / Hermes |
|---|:---:|:---:|:---:|:---:|:---:|
| `external-cli-router` | ✅ | N/A | N/A | N/A | N/A |
| `phone-access-setup` | ✅ | N/A | N/A | N/A | N/A |
| `bell-notifier` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `clipboard-context` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-checkpoint` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `quick-tunnel` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `gemini-cli-router` | ✅ (Preset + Tool) | ✅ (Skill) | ✅ (Skill) | ✅ (Skill) | ✅ (Skill) |

---

## 📄 License
MIT License. Feel free to use, modify, and build on top of these plugins!
