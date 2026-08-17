---
name: gemini-cli-router
description: Delegate a subtask or prompt to Google Gemini 2.0 Flash or Gemini 2.5 Pro without leaving the current session. Use when the user asks to "ask gemini", "delegate to gemini", "get a second opinion from gemini flash", or for ultra-fast, high-context subtasks.
---

# Gemini CLI Router (`delegate-to-gemini`)

One-shot prompt delegation to Google's high-speed, large-context Gemini models (`gemini-2.0-flash`, `gemini-2.5-pro`) directly from any agent session.

## When to Use

- Fast second opinion or alternate perspective on architecture, logic, or debugging.
- Huge context analysis (up to 1M+ tokens) at high speed.
- Summarizing massive documentation or logs.

## Setup

Set your Gemini API key once in your profile:
```powershell
$env:GEMINI_API_KEY = "AIzaSy..."
# Or save in: ~/.config/gemini-key.txt
```

## Commands

```powershell
pwsh -File "<skill-dir>/gemini-run.ps1" -Prompt "Explain how JavaScript event loops handle microtasks" -Model "gemini-2.0-flash"
```

Or pipe a file or git diff into stdin:
```powershell
git diff | pwsh -File "<skill-dir>/gemini-run.ps1" -SystemInstruction "Review this git diff for edge-case bugs"
```
