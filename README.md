# 🤖 External CLI Router for DeepSeek Harness

> **Use Claude Code CLI and OpenAI Codex CLI as selectable models inside DeepSeek Harness — with full thinking effort control, delegation tools, and one-shot subagent support.**

[![DeepSeek Harness Plugin](https://img.shields.io/badge/DeepSeek%20Harness-Dynamic%20Plugin-purple?style=flat-square)](https://github.com/1aifanatic/deepseekharness-musthave)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue?style=flat-square)](https://github.com/1aifanatic/deepseekharness-musthave)

---

## ✨ What You Get

| Integration | How to use it | What it does |
|---|---|---|
| **LLM Adapter** | Select in DSH's model picker | Routes entire agent sessions through `claude -p` or `codex exec` |
| **Delegation Tools** | `delegate_to_claude` / `delegate_to_codex` | One-shot prompts without switching the session model |
| **Subagent Providers** | `subagent_fork(..., { provider: 'claude-cli-oneshot' })` | Stateless Claude/Codex one-shots as background subagents |

### Model Catalog

**Claude Code CLI** (`claude-cli`):
- `sonnet` — Claude Sonnet 4 (default, 200K context)
- `opus` — Claude Opus 4 (200K context)
- `haiku` — Claude Haiku 4 (200K context)
- Thinking effort: **Low / Medium / High** 🎚️ *(selectable in the model picker)*

**OpenAI Codex CLI** (`codex-cli`):
- `default` — CLI picks the best model for your task
- `gpt-5` — GPT-5 (requires API key)
- `gpt-5-codex` — GPT-5 Codex mode (requires API key)
- `o3` — o3 (requires API key)
- `o4-mini` — o4-mini (requires API key)
- Thinking effort: **Low / Medium / High** 🎚️

---

## ⚡ Quick Install (30 seconds)

> Requirements: Windows 10/11, DeepSeek Harness running, Claude Code CLI + Codex CLI installed.

**One-liner:**

```powershell
irm https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/external-cli-router/setup.ps1 | iex
```

That's it. The script copies the plugin files and prints your next step.

---

## 📋 Full Setup Guide

### Step 1 — Install the CLI tools

**Claude Code CLI** — [installation guide](https://docs.anthropic.com/en/docs/claude-code/setup)

```powershell
# Install via npm (requires Node.js)
npm install -g @anthropic/claude-code

# Authenticate
claude auth login
```

**OpenAI Codex CLI** — [installation guide](https://github.com/openai/codex)

```powershell
# Install via pip
pip install codex

# Authenticate (option A: API key)
$env:OPENAI_API_KEY = 'your-key-here'

# Authenticate (option B: interactive)
codex auth login
```

Verify both are working:

```powershell
claude --version
codex --version
```

### Step 2 — Install the DSH plugin

**Option A — Run the install script** *(recommended)*

```powershell
irm https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main/external-cli-router/setup.ps1 | iex
```

**Option B — Manual install**

```powershell
# Create the preset directory
New-Item -ItemType Directory -Force "$env:USERPROFILE\.dsh\.agent-presets\external-cli-router"

# Copy these three files from this repo into that directory:
#   plugin.js
#   preset.yml
#   agent.cordis.yml
```

### Step 3 — Activate the plugin

**Option A — Auto-start (start a new DSH session)**

Restart DSH or open a new session. The preset loads automatically when DSH starts.

**Option B — Activate in any session right now**

1. Load the cordis-plugin-development skill:
   ```
   /skill cordis-plugin-development
   ```

2. Run this **exact code** as two steps in your DSH session:

   **Step 1 — Define the plugin:**
   ```
   cordis_define with plugin={kind:"new",idPrefix:"ecr"}, name="external-cli-router", purpose="Routes DSH model calls to locally installed Claude Code CLI and OpenAI Codex CLI. See https://github.com/1aifanatic/deepseekharness-musthave", code={host:"return { inject: ['llm', 'subprocess', 'subagents'], apply: function(ctx) { var llm = ctx.llm; var subprocess = ctx.subprocess; var subagents = ctx.subagents; var GRACE_MS = 30000; function estimateTokens(text) { return Math.max(0, Math.ceil(((text || '').length) / 4)); } function flattenMessages(options) { var parts = []; if (options.system) parts.push('### System\n' + options.system); var messages = options.messages || []; for (var i = 0; i < messages.length; i++) { var msg = messages[i]; if (!msg || !msg.role) continue; var blocks = msg.content || []; var text = ''; for (var j = 0; j < blocks.length; j++) { var b = blocks[j]; if (b && b.type === 'text') text += (b.text || ''); } if (!text) continue; if (msg.role === 'system') parts.push('### System\n' + text); else if (msg.role === 'user') parts.push('### User\n' + text); else if (msg.role === 'assistant') parts.push('### Assistant\n' + text); else if (msg.role === 'tool') parts.push('### Tool Result\n' + text); } return parts.join('\n\n'); } function promptBlocksToText(promptBlocks) { var out = ''; var blocks = promptBlocks || []; for (var i = 0; i < blocks.length; i++) { var b = blocks[i]; if (b && b.type === 'text') out += (b.text || ''); } return out; } function buildStdoutCollect() { return { maxBytes: 4 * 1024 * 1024, spill: { maxBytes: 64 * 1024 * 1024 } }; } function buildStderrCollect() { return { maxBytes: 256 * 1024, spill: { maxBytes: 1024 * 1024 } }; } function isModelSpecified(model) { return !!(model && model.length > 0 && model !== 'default'); } function spawnWithPrompt(binary, flags, promptText, options) { return subprocess.spawn({ argv: [binary].concat(flags), cwd: (options && options.cwd) || '.', stdio: { stdin: { data: promptText }, stdout: (options && options.pipe) ? 'pipe' : buildStdoutCollect(), stderr: (options && options.pipe) ? 'pipe' : buildStderrCollect(), }, graceMs: GRACE_MS, signal: (options && options.signal) || undefined, }); } async function* streamFromCli(runner, options) { var prompt = flattenMessages(options); var flags = runner.buildFlags(options); var exe = await subprocess.resolveExecutable(runner.binary); var handle = spawnWithPrompt(exe, flags, prompt, { cwd: options && options.cwd, signal: options && options.signal, pipe: true }); var stderrText = ''; if (handle.stderr) { handle.stderr.setEncoding('utf8'); handle.stderr.on('data', function(chunk) { stderrText += chunk; }); handle.stderr.on('error', function() {}); } yield { type: 'block-start', index: 0, blockType: 'text' }; var stdoutText = ''; if (handle.stdout) { handle.stdout.setEncoding('utf8'); try { for await (var chunk of handle.stdout) { stdoutText += chunk; yield { type: 'text-delta', index: 0, text: chunk }; } } catch (e) {} } var outcome = await handle.done; yield { type: 'block-end', index: 0, block: { type: 'text', text: stdoutText } }; yield { type: 'usage', usage: { inputTokens: estimateTokens(prompt), outputTokens: estimateTokens(stdoutText) }, }; var ok = outcome.exitCode === 0 || (runner.softExit && stdoutText.trim().length > 0); if (ok) { yield { type: 'finish', reason: { kind: 'stop' } }; } else { yield { type: 'finish', reason: { kind: 'error', failure: { message: runner.binary + ' exited ' + outcome.exitCode + (outcome.signal ? ' (' + outcome.signal + ')' : '') + ': ' + stderrText.slice(0, 500), code: 'CLI_EXIT', }, }, }; } } function makeAdapter(displayName, runner, models) { return { providerInfo: function(provider) { return { id: provider, name: displayName }; }, providerRetryPolicy: function() { return undefined; }, listModels: function(provider) { return Promise.resolve(models.map(function(m) { return { provider: provider, id: m.id, name: m.name }; })); }, resolveModel: function(provider, modelId) { var m = null; for (var i = 0; i < models.length; i++) { if (models[i].id === modelId) { m = models[i]; break; } } if (!m) m = models[0]; return Promise.resolve({ provider: provider, id: m.id, name: m.name, context: { contextWindow: m.contextWindow }, defaultMaxTokens: m.maxTokens, reasoning: { efforts: runner.efforts.map(function(e) { return { id: e.id, name: e.name }; }), defaultEffort: runner.defaultEffort, }, }); }, stream: function(options) { return streamFromCli(runner, options); }, }; } var CLAUDE_MODELS = [ { id: 'sonnet', name: 'Claude Sonnet (default)', contextWindow: 200000, maxTokens: 16384 }, { id: 'opus', name: 'Claude Opus', contextWindow: 200000, maxTokens: 16384 }, { id: 'haiku', name: 'Claude Haiku', contextWindow: 200000, maxTokens: 16384 }, ]; var CODEX_MODELS = [ { id: 'default', name: 'Codex (CLI default model)', contextWindow: 400000, maxTokens: 128000 }, { id: 'gpt-5', name: 'GPT-5 (API key only)', contextWindow: 400000, maxTokens: 128000 }, { id: 'gpt-5-codex', name: 'GPT-5 Codex (API key only)', contextWindow: 400000, maxTokens: 128000 }, { id: 'o3', name: 'o3 (API key only)', contextWindow: 200000, maxTokens: 100000 }, { id: 'o4-mini', name: 'o4-mini (API key only)', contextWindow: 200000, maxTokens: 100000 }, ]; var claudeRunner = { binary: 'claude', softExit: false, efforts: [ { id: 'low', name: 'Low' }, { id: 'medium', name: 'Medium' }, { id: 'high', name: 'High' }, ], defaultEffort: 'medium', buildFlags: function(options) { var flags = ['-p']; if (isModelSpecified(options && options.model)) { flags.push('--model', options.model); } if (options && options.reasoningEffort && options.reasoningEffort !== 'off') { flags.push('--effort', options.reasoningEffort); } return flags; }, }; var codexRunner = { binary: 'codex', softExit: true, efforts: [ { id: 'low', name: 'Low' }, { id: 'medium', name: 'Medium' }, { id: 'high', name: 'High' }, ], defaultEffort: 'medium', buildFlags: function(options) { var flags = ['exec', '--skip-git-repo-check']; if (isModelSpecified(options && options.model)) { flags.push('-m', options.model); } if (options && options.reasoningEffort && options.reasoningEffort !== 'off') { flags.push('-c', 'model_reasoning_effort=' + options.reasoningEffort); } return flags; }, }; var claudeAdapter = makeAdapter('Claude Code CLI', claudeRunner, CLAUDE_MODELS); var codexAdapter = makeAdapter('Codex CLI', codexRunner, CODEX_MODELS); llm.registerAdapter(['claude-cli'], claudeAdapter); llm.registerAdapter(['codex-cli'], codexAdapter); function makeDelegateTool(name, description, binary, softExit, flagBuilder) { var tool = harness.defineTool({ name: name, description: description, parameters: { prompt: { type: 'string', description: 'The prompt to send to ' + binary + '.', required: true }, model: { type: 'string', description: 'Optional model id/alias.' }, reasoningEffort: { type: 'string', description: 'Optional thinking effort: low, medium, or high.' }, cwd: { type: 'string', description: 'Optional working directory.' }, }, output: { schema: { type: 'object', additionalProperties: false, properties: { ok: { type: 'boolean' }, stdout: { type: 'string' }, stderr: { type: 'string' }, exitCode: { type: 'integer' }, durationMs: { type: 'integer' }, model: { type: 'string' }, }, }, render: function(args, value) { var body = (value && value.stdout) || ''; var errTail = (value && value.stderr) ? '\n\n[stderr]\n' + value.stderr : ''; return [{ type: 'text', text: '```\n' + body + errTail + '\n```\n[ok=' + (value ? value.ok : '?') + ', exit=' + (value ? value.exitCode : '?') + ', ' + (value ? value.durationMs : '?') + 'ms]', }]; }, }, execute: function(args, exec) { var flags = flagBuilder(args); return subprocess.resolveExecutable(binary).then(function(exe) { var spec = { argv: [exe].concat(flags), cwd: args.cwd || '.', stdio: { stdin: { data: args.prompt }, stdout: buildStdoutCollect(), stderr: buildStderrCollect(), }, graceMs: GRACE_MS, signal: exec.signal, }; var start = Date.now(); var handle = subprocess.spawn(spec); return handle.done.then(function(outcome) { var stdout = '', stderr = ''; try { stdout = handle.collected.stdout.readFrom(0).text; } catch (e) {} try { stderr = handle.collected.stderr.readFrom(0).text; } catch (e) {} var ok = outcome.exitCode === 0 || (softExit && stdout.trim().length > 0); return { ok: ok, stdout: stdout, stderr: stderr, exitCode: outcome.exitCode, durationMs: Date.now() - start, model: args.model || 'default', }; }); }); }, }); harness.registerTool(ctx, tool); } makeDelegateTool('delegate_to_claude', 'Delegate a one-shot prompt to the locally installed Anthropic Claude Code CLI (claude -p).', 'claude', false, function(args) { var flags = ['-p']; if (isModelSpecified(args.model)) flags.push('--model', args.model); if (args.reasoningEffort && args.reasoningEffort !== 'off') { flags.push('--effort', args.reasoningEffort); } return flags; }); makeDelegateTool('delegate_to_codex', 'Delegate a one-shot prompt to the locally installed OpenAI Codex CLI (codex exec).', 'codex', true, function(args) { var flags = ['exec', '--skip-git-repo-check']; if (isModelSpecified(args.model)) flags.push('-m', args.model); if (args.reasoningEffort && args.reasoningEffort !== 'off') { flags.push('-c', 'model_reasoning_effort=' + args.reasoningEffort); } return flags; }); function registerOneShotProvider(providerName, binary, softExit, flagBuilder) { subagents.registerProvider({ name: providerName, capabilities: { outputSchema: false, depthLimit: false, toolFilter: false, persona: false, }, inheritsParentContext: false, start: function(request) { var promptText = promptBlocksToText(request.prompt); var flags = flagBuilder(); var id = providerName + '-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8); var handle = null; return subprocess.resolveExecutable(binary).then(function(exe) { handle = subprocess.spawn({ argv: [exe].concat(flags), cwd: '.', stdio: { stdin: { data: promptText }, stdout: buildStdoutCollect(), stderr: buildStderrCollect(), }, graceMs: GRACE_MS, signal: request.signal, }); return handle.done; }).then(function(outcome) { var stdout = '', stderr = ''; try { stdout = handle.collected.stdout.readFrom(0).text; } catch (e) {} try { stderr = handle.collected.stderr.readFrom(0).text; } catch (e) {} var ok = outcome.exitCode === 0 || (softExit && stdout.trim().length > 0); return { id: id, localAgent: undefined, result: Promise.resolve({ output: [{ type: 'text', text: stdout || ('(no output; stderr: ' + (stderr || '').slice(0, 500) + ')') }], stopReason: ok ? 'completed' : 'error', }), dispose: function() { try { if (handle) handle.terminate(); } catch (e) {} }, }; }).catch(function(e) { return { id: id, localAgent: undefined, result: Promise.resolve({ output: [{ type: 'text', text: 'Error: ' + String(e) }], stopReason: 'error', }), dispose: function() { try { if (handle) handle.terminate(); } catch (e) {} }, }; }); }, }); } registerOneShotProvider('claude-cli-oneshot', 'claude', false, function() { return ['-p']; }); registerOneShotProvider('codex-cli-oneshot', 'codex', true, function() { return ['exec', '--skip-git-repo-check']; }); } };"}
   ```

   **Step 2 — Activate:**
   ```
   cordis_run with pluginId="<output from step 1>", packageId="<output from step 1>", mode="run"
   ```

*(The exact IDs are returned by step 1. Paste them into step 2.)*

### Step 4 — Verify

1. Open a **new DSH session** (or refresh).
2. Click the **model picker** at the top of the chat.
3. You should see:
   - `Claude Code CLI` — Sonnet / Opus / Haiku, with a **Low / Medium / High** effort dropdown
   - `Codex CLI` — Default / GPT-5 / o3 / o4-mini, with the same effort dropdown

---

## 🎚️ Thinking Effort Guide

The plugin forwards **Low / Medium / High** thinking effort to the CLIs:

| Effort | Claude Code flag | Codex config |
|---|---|---|
| Low | `--effort low` | `-c model_reasoning_effort=low` |
| Medium | `--effort medium` | `-c model_reasoning_effort=medium` |
| High | `--effort high` | `-c model_reasoning_effort=high` |

The effort selector appears in the model picker when you select `claude-cli` or `codex-cli`.

**Defaults:** Medium for both CLIs. To change the session default, use the DSH model picker to select an effort level before starting a conversation.

---

## 🔧 Usage Examples

### Model picker — route the whole session

```
1. Select "Claude Code CLI → sonnet" in the model picker
2. Select thinking effort: "High"
3. Chat normally — every turn goes through Claude Code CLI
```

### Delegation tools — one-shot without switching

```
Ask me: "Delegate to Claude Code to explain what a monad is, in one sentence."
```
*(Uses the delegate_to_claude tool directly — session model stays on DeepSeek.)*

```
Ask me: "Delegate to Codex to write a Python quicksort function."
```
*(Uses delegate_to_codex tool — useful for quick code generation without changing context.)*

### Subagent providers — background work

```javascript
subagent_fork(
  "Write a comprehensive test suite for my REST API. Save to tests/",
  { provider: 'claude-cli-oneshot', model: 'opus' }
)
// Runs in background; result comes back as a message
```

---

## 🌐 OmniRoute / Custom Gateway Support

If you run a local LLM gateway (like [OmniRoute](https://github.com/your-omniroute)), you can add it as a provider in `~/.dsh/settings.yaml`:

```yaml
llm-pi-ai:
  providers:
    omni:
      displayName: OmniRoute (agy+codex+claude)
      api: openai-completions
      baseURL: http://127.0.0.1:20128/v1
      apiKeyEnv: OMNIROUTE_API_KEY    # add this line
```

Then add the credential:

```yaml
# ~/.dsh/.credentials.yaml
OMNIROUTE_API_KEY: any-value-here   # gateway ignores the value; DSH needs it
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---|---|
| Model picker doesn't show claude-cli / codex-cli | Reload the DSH page. If still missing, the plugin failed to activate — check the Run card for errors. |
| "no API key from provider" for OmniRoute | Add `apiKeyEnv: OMNIROUTE_API_KEY` to the omni profile in settings.yaml, and add the key to .credentials.yaml (see OmniRoute section above). |
| Thinking effort dropdown doesn't appear | The plugin needs to be running. Try refreshing the page or restarting the session. |
| "claude: command not found" | Add Claude Code CLI to your PATH, or use the full path in the plugin's `claudeRunner.binary` setting. |
| "codex: command not found" | Add Codex CLI to your PATH. `pip install codex` usually puts it in `%LOCALAPPDATA%\Programs\Python\...` |
| Codex always exits with code 1 | This is expected — Codex exits 1 due to MCP transport noise even on success. The plugin treats non-zero exit + non-empty stdout as success automatically. |
| Prompt too long error | This shouldn't happen — the plugin sends prompts via stdin, bypassing Windows' 32,767-char limit. If you see it, file an issue. |

---

## 🔬 How It Works

### Architecture

```
DSH Session
    │
    ├── Model picker selects "claude-cli / codex-cli"
    │
    ├── LLM call → llm.registerAdapter() → streamFromCli()
    │       │
    │       └── subprocess.spawn({ argv: ['claude', '-p', ...],
    │                              stdio: { stdin: { data: prompt } } })
    │              │
    │              └── Claude Code CLI / Codex CLI
    │                      │
    │                      └── stdout → stream chunks → DSH response
    │
    ├── delegate_to_claude / delegate_to_codex tools
    │       └── harness.defineTool() + harness.registerTool()
    │               │
    │               └── Same stdin-pipe subprocess pattern
    │
    └── subagent providers
            └── subagents.registerProvider()
                    │
                    └── One-shot subprocess, result returned as text
```

### Why stdin instead of a positional argument?

Windows has a **32,767-character command-line limit** (`CreateProcess`). A full DSH conversation with system prompt + history easily exceeds this. Sending the prompt via **stdin** has no length limit.

Both `claude -p` and `codex exec` read from stdin when no positional prompt argument is given — this is the documented stdin-pipe pattern for both CLIs.

---

## 🤝 Contributing

Issues, feature requests, and PRs welcome:

```
https://github.com/1aifanatic/deepseekharness-musthave/issues
```

---

## 📄 License

MIT — see [LICENSE](LICENSE)
