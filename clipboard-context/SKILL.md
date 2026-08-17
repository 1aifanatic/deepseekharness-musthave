---
name: clipboard-context
description: Read and sanitize text, code snippets, error logs, or screenshots currently on the user's OS clipboard. Use when the user says "look at my clipboard", "what did I copy", "read clipboard", "analyze the snippet I just copied", or asks to inspect copied text or image.
---

# Clipboard Context (`/clip`)

Instantly grab and sanitize content directly from the host operating system's clipboard without requiring the user to paste large blocks of text into the chat prompt.

## When to Use

- User says: *"Look at what I just copied"*, *"Check my clipboard"*, *"Read the error in my clipboard"*, *"Analyze my screenshot"*.
- The user copied a traceback, URL, or JSON blob from their browser/terminal and wants the agent to inspect it immediately.

## Workflow

1. Execute the grabber script:
   - **Windows (PowerShell)**:
     ```powershell
     pwsh -File "<skill-dir>/grab-clip.ps1"
     ```
   - **macOS**:
     ```bash
     pbpaste
     ```
   - **Linux**:
     ```bash
     xclip -selection clipboard -o || wl-paste
     ```

2. **If text is returned**: Parse the cleaned content directly and answer the user's request.
3. **If image is detected**: The script outputs `[CLIPBOARD_IMAGE_SAVED: <path>]`. Read the image using image tools (`read_image`) or vision APIs to inspect the screenshot.
