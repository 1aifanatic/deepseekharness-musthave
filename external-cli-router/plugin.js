/**
 * external-cli-router — DeepSeek Harness Dynamic Plugin
 * =====================================================
 *
 * Routes DSH model calls, delegation tools, and subagent providers to:
 *   - Anthropic Claude Code CLI  (claude -p)
 *   - OpenAI Codex CLI          (codex exec --skip-git-repo-check)
 *
 * INSTALLATION — two steps:
 *
 *  Step 1: Place this file at:
 *    %USERPROFILE%\.dsh\.agent-presets\external-cli-router\plugin.js
 *
 *  Step 2: Create the preset metadata at:
 *    %USERPROFILE%\.dsh\.agent-presets\external-cli-router\preset.yml
 *    (content: see the preset.yml file in this repository)
 *
 *  Step 3: Restart DSH or start a new session. The plugin auto-activates.
 *
 * ALTERNATIVELY — activate from any DSH session without a preset:
 *    Load the cordis-plugin-development skill, then run:
 *      cordis_define + cordis_run with the contents of this file
 *    (see the README for the exact one-liner)
 *
 * WHAT YOU GET
 * -------------
 * 1. Model picker integration
 *    claude-cli  →  sonnet / opus / haiku  (+ Low/Medium/High thinking effort)
 *    codex-cli   →  default / gpt-5 / gpt-5-codex / o3 / o4-mini
 *
 * 2. Delegation tools  (call from any session as a tool)
 *    delegate_to_claude  — one-shot prompt to Claude Code CLI
 *    delegate_to_codex   — one-shot prompt to Codex CLI
 *    Both accept: prompt, model, reasoningEffort, cwd
 *
 * 3. Subagent providers  (use with subagent_fork / subagent)
 *    claude-cli-oneshot  — stateless one-shot via Claude Code CLI
 *    codex-cli-oneshot   — stateless one-shot via Codex CLI
 *
 * WINDOWS NOTE
 * Prompts are sent via stdin (not a positional argument), bypassing the
 * 32,767-character CreateProcess command-line limit. Both `claude -p` and
 * `codex exec` read the prompt from stdin when no positional arg is given.
 *
 * CREDENTIALS
 * Claude Code: uses its own stored OAuth/API key  (~/.claude/.credentials)
 * Codex CLI:   uses ~/.codex/auth.json or OPENAI_API_KEY env var
 */

'use strict';

return {
  inject: ['llm', 'subprocess', 'subagents'],

  apply: function (ctx) {
    var llm = ctx.llm;
    var subprocess = ctx.subprocess;
    var subagents = ctx.subagents;

    var GRACE_MS = 30000;

    function estimateTokens(text) {
      return Math.max(0, Math.ceil(((text || '').length) / 4));
    }

    function flattenMessages(options) {
      var parts = [];
      if (options.system) parts.push('### System\n' + options.system);
      var messages = options.messages || [];
      for (var i = 0; i < messages.length; i++) {
        var msg = messages[i];
        if (!msg || !msg.role) continue;
        var blocks = msg.content || [];
        var text = '';
        for (var j = 0; j < blocks.length; j++) {
          var b = blocks[j];
          if (b && b.type === 'text') text += (b.text || '');
        }
        if (!text) continue;
        if (msg.role === 'system')      parts.push('### System\n' + text);
        else if (msg.role === 'user')    parts.push('### User\n' + text);
        else if (msg.role === 'assistant') parts.push('### Assistant\n' + text);
        else if (msg.role === 'tool')   parts.push('### Tool Result\n' + text);
      }
      return parts.join('\n\n');
    }

    function promptBlocksToText(promptBlocks) {
      var out = '';
      var blocks = promptBlocks || [];
      for (var i = 0; i < blocks.length; i++) {
        var b = blocks[i];
        if (b && b.type === 'text') out += (b.text || '');
      }
      return out;
    }

    function buildStdoutCollect() {
      return { maxBytes: 4 * 1024 * 1024, spill: { maxBytes: 64 * 1024 * 1024 } };
    }
    function buildStderrCollect() {
      return { maxBytes: 256 * 1024, spill: { maxBytes: 1024 * 1024 } };
    }

    function isModelSpecified(model) {
      return !!(model && model.length > 0 && model !== 'default');
    }

    // Spawn a CLI whose prompt is delivered through stdin (not argv).
    // On Windows, a positional prompt hits the 32,767-char CreateProcess limit;
    // stdin has no such limit. Both `claude -p` and `codex exec` read from
    // stdin when no positional argument is given.
    function spawnWithPrompt(binary, flags, promptText, options) {
      return subprocess.spawn({
        argv: [binary].concat(flags),
        cwd: (options && options.cwd) || '.',
        stdio: {
          stdin: { data: promptText },
          stdout: (options && options.pipe) ? 'pipe' : buildStdoutCollect(),
          stderr: (options && options.pipe) ? 'pipe' : buildStderrCollect(),
        },
        graceMs: GRACE_MS,
        signal: (options && options.signal) || undefined,
      });
    }

    // Async generator that yields DSH StreamChunk objects.
    async function* streamFromCli(runner, options) {
      var prompt = flattenMessages(options);
      var flags = runner.buildFlags(options);
      var exe = await subprocess.resolveExecutable(runner.binary);
      var handle = spawnWithPrompt(exe, flags, prompt, {
        cwd: options && options.cwd,
        signal: options && options.signal,
        pipe: true,
      });

      var stderrText = '';
      if (handle.stderr) {
        handle.stderr.setEncoding('utf8');
        handle.stderr.on('data', function (chunk) { stderrText += chunk; });
        handle.stderr.on('error', function () {});
      }

      yield { type: 'block-start', index: 0, blockType: 'text' };

      var stdoutText = '';
      if (handle.stdout) {
        handle.stdout.setEncoding('utf8');
        try {
          for await (var chunk of handle.stdout) {
            stdoutText += chunk;
            yield { type: 'text-delta', index: 0, text: chunk };
          }
        } catch (e) {
          // Process died mid-stream; finish chunk below reports the cause.
        }
      }

      var outcome = await handle.done;

      yield { type: 'block-end', index: 0, block: { type: 'text', text: stdoutText } };
      yield {
        type: 'usage',
        usage: {
          inputTokens: estimateTokens(prompt),
          outputTokens: estimateTokens(stdoutText),
        },
      };

      // Soft-exit: Codex CLI exits 1 due to MCP transport noise even when it
      // produced valid output. Treat non-zero exit as success when stdout has
      // substantive content.
      var ok = outcome.exitCode === 0 ||
        (runner.softExit && stdoutText.trim().length > 0);

      if (ok) {
        yield { type: 'finish', reason: { kind: 'stop' } };
      } else {
        yield {
          type: 'finish',
          reason: {
            kind: 'error',
            failure: {
              message: runner.binary + ' exited ' + outcome.exitCode +
                (outcome.signal ? ' (' + outcome.signal + ')' : '') +
                ': ' + stderrText.slice(0, 500),
              code: 'CLI_EXIT',
            },
          },
        };
      }
    }

    // -------------------------------------------------------------------------
    // Adapter factory
    // -------------------------------------------------------------------------
    function makeAdapter(displayName, runner, models) {
      return {
        providerInfo: function (provider) {
          return { id: provider, name: displayName };
        },
        providerRetryPolicy: function () {
          return undefined;
        },
        listModels: function (provider) {
          return Promise.resolve(models.map(function (m) {
            return { provider: provider, id: m.id, name: m.name };
          }));
        },
        resolveModel: function (provider, modelId) {
          var m = null;
          for (var i = 0; i < models.length; i++) {
            if (models[i].id === modelId) { m = models[i]; break; }
          }
          if (!m) m = models[0];
          return Promise.resolve({
            provider: provider,
            id: m.id,
            name: m.name,
            context: { contextWindow: m.contextWindow },
            defaultMaxTokens: m.maxTokens,
            // Advertise thinking effort levels so the model picker shows them.
            reasoning: {
              efforts: runner.efforts.map(function (e) {
                return { id: e.id, name: e.name };
              }),
              defaultEffort: runner.defaultEffort,
            },
          });
        },
        stream: function (options) {
          return streamFromCli(runner, options);
        },
      };
    }

    // -------------------------------------------------------------------------
    // Model catalogs
    // -------------------------------------------------------------------------
    var CLAUDE_MODELS = [
      { id: 'sonnet', name: 'Claude Sonnet (default)', contextWindow: 200000, maxTokens: 16384 },
      { id: 'opus',   name: 'Claude Opus',              contextWindow: 200000, maxTokens: 16384 },
      { id: 'haiku',  name: 'Claude Haiku',             contextWindow: 200000, maxTokens: 16384 },
    ];

    var CODEX_MODELS = [
      // 'default' — CLI picks. Works with ChatGPT OAuth or API-key auth.
      { id: 'default',     name: 'Codex (CLI default model)', contextWindow: 400000, maxTokens: 128000 },
      // API-key-only models. ChatGPT-account users get a 400 from these.
      { id: 'gpt-5',       name: 'GPT-5 (API key only)',       contextWindow: 400000, maxTokens: 128000 },
      { id: 'gpt-5-codex', name: 'GPT-5 Codex (API key only)', contextWindow: 400000, maxTokens: 128000 },
      { id: 'o3',          name: 'o3 (API key only)',          contextWindow: 200000, maxTokens: 100000 },
      { id: 'o4-mini',     name: 'o4-mini (API key only)',     contextWindow: 200000, maxTokens: 100000 },
    ];

    // -------------------------------------------------------------------------
    // CLI runners
    // -------------------------------------------------------------------------
    var claudeRunner = {
      binary: 'claude',
      softExit: false,
      efforts: [
        { id: 'low',    name: 'Low' },
        { id: 'medium', name: 'Medium' },
        { id: 'high',   name: 'High' },
      ],
      defaultEffort: 'medium',
      buildFlags: function (options) {
        var flags = ['-p'];
        if (isModelSpecified(options && options.model)) {
          flags.push('--model', options.model);
        }
        if (options && options.reasoningEffort && options.reasoningEffort !== 'off') {
          flags.push('--effort', options.reasoningEffort);
        }
        return flags;
      },
    };

    var codexRunner = {
      binary: 'codex',
      softExit: true,   // Codex exits 1 due to MCP transport noise even on success.
      efforts: [
        { id: 'low',    name: 'Low' },
        { id: 'medium', name: 'Medium' },
        { id: 'high',   name: 'High' },
      ],
      defaultEffort: 'medium',
      buildFlags: function (options) {
        var flags = ['exec', '--skip-git-repo-check'];
        if (isModelSpecified(options && options.model)) {
          flags.push('-m', options.model);
        }
        if (options && options.reasoningEffort && options.reasoningEffort !== 'off') {
          flags.push('-c', 'model_reasoning_effort=' + options.reasoningEffort);
        }
        return flags;
      },
    };

    // -------------------------------------------------------------------------
    // Register LLM adapters — appears in DSH's model picker as:
    //   "Claude Code CLI"  and  "Codex CLI"
    // -------------------------------------------------------------------------
    var claudeAdapter = makeAdapter('Claude Code CLI', claudeRunner, CLAUDE_MODELS);
    var codexAdapter  = makeAdapter('Codex CLI',        codexRunner,  CODEX_MODELS);

    llm.registerAdapter(['claude-cli'], claudeAdapter);
    llm.registerAdapter(['codex-cli'],  codexAdapter);

    // -------------------------------------------------------------------------
    // Delegation tools — callable directly from any DSH session.
    // -------------------------------------------------------------------------
    function makeDelegateTool(name, description, binary, softExit, flagBuilder) {
      var tool = harness.defineTool({
        name: name,
        description: description,
        parameters: {
          prompt: {
            type: 'string',
            description: 'The prompt to send to ' + binary + '.',
            required: true,
          },
          model: {
            type: 'string',
            description: 'Optional model id/alias. Pass "default" to let the CLI pick.',
          },
          reasoningEffort: {
            type: 'string',
            description: 'Optional thinking effort: low, medium, or high.',
          },
          cwd: {
            type: 'string',
            description: 'Optional working directory for the CLI process.',
          },
        },
        output: {
          schema: {
            type: 'object',
            additionalProperties: false,
            properties: {
              ok:         { type: 'boolean' },
              stdout:     { type: 'string' },
              stderr:     { type: 'string' },
              exitCode:   { type: 'integer' },
              durationMs: { type: 'integer' },
              model:      { type: 'string' },
            },
          },
          render: function (args, value) {
            var body = (value && value.stdout) || '';
            var errTail = (value && value.stderr)
              ? '\n\n[stderr]\n' + value.stderr
              : '';
            return [{
              type: 'text',
              text: '```\n' + body + errTail + '\n```\n[ok=' +
                (value ? value.ok : '?') + ', exit=' +
                (value ? value.exitCode : '?') + ', ' +
                (value ? value.durationMs : '?') + 'ms]',
            }];
          },
        },
        execute: function (args, exec) {
          var flags = flagBuilder(args);
          return subprocess.resolveExecutable(binary).then(function (exe) {
            var spec = {
              argv: [exe].concat(flags),
              cwd: args.cwd || '.',
              stdio: {
                stdin: { data: args.prompt },
                stdout: buildStdoutCollect(),
                stderr: buildStderrCollect(),
              },
              graceMs: GRACE_MS,
              signal: exec.signal,
            };
            var start = Date.now();
            var handle = subprocess.spawn(spec);
            return handle.done.then(function (outcome) {
              var stdout = '';
              var stderr = '';
              try { stdout = handle.collected.stdout.readFrom(0).text; } catch (e) {}
              try { stderr = handle.collected.stderr.readFrom(0).text; } catch (e) {}
              var ok = outcome.exitCode === 0 || (softExit && stdout.trim().length > 0);
              return {
                ok: ok,
                stdout: stdout,
                stderr: stderr,
                exitCode: outcome.exitCode,
                durationMs: Date.now() - start,
                model: args.model || 'default',
              };
            });
          });
        },
      });
      harness.registerTool(ctx, tool);
    }

    makeDelegateTool(
      'delegate_to_claude',
      'Delegate a one-shot prompt to the locally installed Anthropic Claude Code CLI (claude -p). ' +
      'The CLI inherits stored Claude Code auth (OAuth / API key) from this machine. Use when you ' +
      'want Claude to handle a focused subtask without changing the main agent.',
      'claude',
      false,
      function (args) {
        var flags = ['-p'];
        if (isModelSpecified(args.model)) flags.push('--model', args.model);
        if (args.reasoningEffort && args.reasoningEffort !== 'off') {
          flags.push('--effort', args.reasoningEffort);
        }
        return flags;
      }
    );

    makeDelegateTool(
      'delegate_to_codex',
      'Delegate a one-shot prompt to the locally installed OpenAI Codex CLI (codex exec). ' +
      'The CLI inherits stored Codex auth (chatgpt OAuth or ~/.codex/auth.json) from this machine. ' +
      'Use when you want GPT-5/o3/o4-mini for a focused subtask without changing the main agent. ' +
      'Pass model="default" to let the CLI pick.',
      'codex',
      true,
      function (args) {
        var flags = ['exec', '--skip-git-repo-check'];
        if (isModelSpecified(args.model)) flags.push('-m', args.model);
        if (args.reasoningEffort && args.reasoningEffort !== 'off') {
          flags.push('-c', 'model_reasoning_effort=' + args.reasoningEffort);
        }
        return flags;
      }
    );

    // -------------------------------------------------------------------------
    // Subagent providers — use with subagent_fork / subagent:
    //   subagent_fork(prompt, { provider: 'claude-cli-oneshot' })
    //   subagent_fork(prompt, { provider: 'codex-cli-oneshot' })
    // -------------------------------------------------------------------------
    function registerOneShotProvider(providerName, binary, softExit, flagBuilder) {
      subagents.registerProvider({
        name: providerName,
        capabilities: {
          outputSchema: false,
          depthLimit: false,
          toolFilter: false,
          persona: false,
        },
        inheritsParentContext: false,
        start: function (request) {
          var promptText = promptBlocksToText(request.prompt);
          var flags = flagBuilder();
          var id = providerName + '-' + Date.now().toString(36) + '-' +
            Math.random().toString(36).slice(2, 8);
          var handle = null;

          return subprocess.resolveExecutable(binary).then(function (exe) {
            handle = subprocess.spawn({
              argv: [exe].concat(flags),
              cwd: '.',
              stdio: {
                stdin: { data: promptText },
                stdout: buildStdoutCollect(),
                stderr: buildStderrCollect(),
              },
              graceMs: GRACE_MS,
              signal: request.signal,
            });
            return handle.done;
          }).then(function (outcome) {
            var stdout = '';
            var stderr = '';
            try { stdout = handle.collected.stdout.readFrom(0).text; } catch (e) {}
            try { stderr = handle.collected.stderr.readFrom(0).text; } catch (e) {}
            var ok = outcome.exitCode === 0 || (softExit && stdout.trim().length > 0);
            return {
              id: id,
              localAgent: undefined,
              result: Promise.resolve({
                output: [{
                  type: 'text',
                  text: stdout || ('(no output; stderr: ' + (stderr || '').slice(0, 500) + ')'),
                }],
                stopReason: ok ? 'completed' : 'error',
              }),
              dispose: function () {
                try { if (handle) handle.terminate(); } catch (e) {}
              },
            };
          }).catch(function (e) {
            return {
              id: id,
              localAgent: undefined,
              result: Promise.resolve({
                output: [{ type: 'text', text: 'Error: ' + String(e) }],
                stopReason: 'error',
              }),
              dispose: function () {
                try { if (handle) handle.terminate(); } catch (e) {}
              },
            };
          });
        },
      });
    }

    registerOneShotProvider('claude-cli-oneshot', 'claude', false, function () {
      return ['-p'];
    });

    registerOneShotProvider('codex-cli-oneshot', 'codex', true, function () {
      return ['exec', '--skip-git-repo-check'];
    });
  },
};
