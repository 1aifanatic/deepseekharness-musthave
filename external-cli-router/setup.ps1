<#
.SYNOPSIS
  Installs the External CLI Router plugin for DeepSeek Harness:
  Claude Code CLI + OpenAI Codex CLI as selectable models inside DSH.

.DESCRIPTION
  This script:
    1. Checks that the Claude Code CLI and Codex CLI are installed and on PATH.
    2. Copies the plugin and preset files to %USERPROFILE%\.dsh\.agent-presets\external-cli-router\
    3. Prints next steps.

  Run it once. It is idempotent — re-running it upgrades to the latest version.

  Requirements: PowerShell 5.1+ or 7+, Windows 10/11.

.NOTES
  Source:  https://github.com/1aifanatic/deepseekharness-musthave
  Issues:  https://github.com/1aifanatic/deepseekharness-musthave/issues
#>

param(
    [switch]$SkipCliCheck,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "    $msg" -ForegroundColor Red }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Magenta
Write-Host ' External CLI Router — DeepSeek Harness plugin installer' -ForegroundColor Magenta
Write-Host '============================================================' -ForegroundColor Magenta

# ------------------------------------------------------------ 1. Check CLIs
if (-not $SkipCliCheck) {
    Write-Step 'Checking CLI prerequisites...'

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        try {
            $ver = & claude --version 2>&1 | Select-Object -First 1
            Write-Ok "Claude Code CLI found: $ver"
        } catch {
            Write-Ok 'Claude Code CLI found (version check failed — CLI may need auth)'
        }
    } else {
        Write-Warn 'Claude Code CLI not found on PATH.'
        Write-Warn '  Install: https://docs.anthropic.com/en/docs/claude-code/setup'
        Write-Warn '  Then run: claude auth login'
    }

    $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($codexCmd) {
        try {
            $ver = & codex --version 2>&1 | Select-Object -First 1
            Write-Ok "Codex CLI found: $ver"
        } catch {
            Write-Ok 'Codex CLI found (version check failed — CLI may need auth)'
        }
    } else {
        Write-Warn 'Codex CLI not found on PATH.'
        Write-Warn '  Install: pip install codex'
        Write-Warn '  Then set OPENAI_API_KEY env var, or run: codex auth login'
    }

    Write-Host ''
    $continue = Read-Host 'Continue anyway? (y/N)'
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host 'Aborted.' -ForegroundColor Yellow
        return
    }
}

# ------------------------------------------------------------ 2. Create preset dir
Write-Step 'Creating DeepSeek Harness agent-preset directory...'
$DshPresetDir = Join-Path $env:USERPROFILE '.dsh\.agent-presets\external-cli-router'
if (-not (Test-Path $DshPresetDir)) {
    New-Item -ItemType Directory -Path $DshPresetDir -Force | Out-Null
    Write-Ok "Created: $DshPresetDir"
} else {
    Write-Ok "Already exists: $DshPresetDir"
}

# ------------------------------------------------------------ 3. Copy plugin files
Write-Step 'Copying plugin files...'

$files = @{
    'plugin.js'        = 'plugin.js'
    'preset.yml'      = 'preset.yml'
    'agent.cordis.yml' = 'agent.cordis.yml'
}

foreach ($file in $files.Keys) {
    $src = Join-Path $RepoRoot 'external-cli-router' $file
    $dst = Join-Path $DshPresetDir $files[$file]
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Ok "Copied: $file  →  $dst"
    } else {
        if ($Force) {
            Write-Warn "Source file not found (skipping): $src"
        } else {
            Write-Err "Source file not found: $src"
            Write-Err 'Are you running this script from the cloned repository?'
            Write-Err "Expected repo root: $RepoRoot"
        }
    }
}

# ------------------------------------------------------------ 4. Verify
Write-Step 'Verifying installation...'
$pluginJs = Join-Path $DshPresetDir 'plugin.js'
if (Test-Path $pluginJs) {
    $content = Get-Content $pluginJs -Raw -ErrorAction SilentlyContinue
    if ($content -match 'claude-cli.*registerAdapter') {
        Write-Ok 'plugin.js looks correct (found registerAdapter call)'
    } else {
        Write-Warn 'plugin.js exists but may not be the right file — check it manually'
    }
} else {
    Write-Err 'plugin.js was NOT copied — installation incomplete'
}

# ------------------------------------------------------------ 5. Next steps
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' INSTALLATION COMPLETE' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'NEXT STEPS:'
Write-Host ''
Write-Host 'Option A — Auto-start (recommended):'
Write-Host '  Restart DSH or start a new session. The preset loads automatically.'
Write-Host ''
Write-Host 'Option B — Activate now (any session):'
Write-Host '  1. Load the cordis-plugin-development skill:'
Write-Host '       /skill cordis-plugin-development'
Write-Host ''
Write-Host '  2. In the same session, run:'
Write-Host "       cordis_define + cordis_run"
Write-Host '     (use the EXACT code from the README — the one-liner)'
Write-Host ''
Write-Host 'VERIFICATION:'
Write-Host '  In DSH, open the model picker (top of session). You should see:'
Write-Host '    - "Claude Code CLI"  (sonnet / opus / haiku + thinking effort)'
Write-Host '    - "Codex CLI"        (default / gpt-5 / o3 / o4-mini)'
Write-Host ''
Write-Host '  Also, these tools are now available:'
Write-Host '    delegate_to_claude   — "Ask Claude Code to ..."'
Write-Host '    delegate_to_codex    — "Ask Codex to ..."'
Write-Host ''
Write-Host 'DOCS:  https://github.com/1aifanatic/deepseekharness-musthave'
Write-Host ''
