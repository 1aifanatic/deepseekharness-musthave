---
name: bell-notifier
description: Send an instant push notification or sound chime to your phone or desktop (via free ntfy.sh, Discord, Telegram, or system audio) when a long task, test run, or goal finishes. Use when the user asks to "notify me when done", "send a ding", "ping my phone", "alert me", or after finishing heavy autonomous work.
---

# Bell Notifier (`ding`)

Send an instant notification to the user's phone, Discord, Telegram, or local desktop speaker when work finishes or needs attention.

## When to Use

- When the user says *"ping me when done"*, *"notify my phone"*, *"send a ding"*, or *"alert me on Discord/Telegram"*.
- At the conclusion of a long build, test suite execution, or multi-step autonomous goal.
- When an agent is blocked and waiting for human review or input.

## How to Trigger

### 1. Free Phone Push via ntfy.sh (Zero Login Required)

The user can subscribe to any private topic name on the free [ntfy app (iOS / Android / Web)](https://ntfy.sh).

Execute via PowerShell:
```powershell
pwsh -File "<skill-dir>/notify.ps1" -Message "Task complete: Built and tested user auth" -Title "Agent Done" -Topic "your-private-topic"
```

Or configure once in `$HOME/.config/agent-notify.json`:
```json
{
  "topic": "my-secret-agent-alerts",
  "discordWebhook": "https://discord.com/api/webhooks/...",
  "telegramToken": "...",
  "telegramChatId": "..."
}
```

Then simply call:
```powershell
pwsh -File "<skill-dir>/notify.ps1" -Message "All 42 tests passed!" -Title "Build Green"
```

### 2. Zero-Config Local Desktop Chime
If no webhook or topic is configured, running `notify.ps1` plays a quick double chime through the system audio speaker and prints instructions on configuring mobile alerts.
