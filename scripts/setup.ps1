# Universal Installer for Must-Have AI Agent Skills & Plugins
# ============================================================
# DeepSeek Harness, Claude Code, OpenAI Codex, Cursor, Cline

param(
    [switch]$Force
)

$ErrorActionPreference = "Continue"

Write-Host "`n============================================================" -ForegroundColor Magenta
Write-Host " 🚀 Installing DeepSeek Harness Must-Have Suite" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$repoRoot = Split-Path -Parent $scriptRoot

# Target directories
$agentsSkillsDir = "$env:USERPROFILE\.agents\skills"
$claudeSkillsDir = "$env:USERPROFILE\.claude\skills"
$dshPresetsDir = "$env:USERPROFILE\.dsh\.agent-presets"

if (-not (Test-Path $agentsSkillsDir)) { New-Item -ItemType Directory -Path $agentsSkillsDir -Force | Out-Null }
if (-not (Test-Path $claudeSkillsDir)) { New-Item -ItemType Directory -Path $claudeSkillsDir -Force | Out-Null }
if (-not (Test-Path $dshPresetsDir)) { New-Item -ItemType Directory -Path $dshPresetsDir -Force | Out-Null }

$skillNames = @(
    "bell-notifier",
    "clipboard-context",
    "git-checkpoint",
    "quick-tunnel",
    "gemini-cli-router"
)

$rawBaseUrl = "https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main"

foreach ($name in $skillNames) {
    Write-Host "`n==> Installing $name..." -ForegroundColor Cyan
    $destAgent = Join-Path $agentsSkillsDir $name
    if (-not (Test-Path $destAgent)) { New-Item -ItemType Directory -Path $destAgent -Force | Out-Null }
    
    $localSkillDir = Join-Path $repoRoot $name
    if (Test-Path $localSkillDir) {
        # Local copy
        Copy-Item -Path "$localSkillDir\*" -Destination $destAgent -Recurse -Force
        Write-Host "    Installed from local workspace: $destAgent" -ForegroundColor Green
    } else {
        # Remote download fallback
        Write-Host "    Downloading skill files from GitHub..." -ForegroundColor Gray
        $filesToDownload = switch ($name) {
            "bell-notifier"     { @("SKILL.md", "notify.ps1") }
            "clipboard-context" { @("SKILL.md", "grab-clip.ps1") }
            "git-checkpoint"    { @("SKILL.md", "checkpoint.ps1") }
            "quick-tunnel"      { @("SKILL.md", "tunnel.ps1") }
            "gemini-cli-router" { @("SKILL.md", "gemini-run.ps1", "plugin.js", "preset.yml") }
        }
        foreach ($f in $filesToDownload) {
            $fUrl = "$rawBaseUrl/$name/$f"
            $fDest = Join-Path $destAgent $f
            try {
                Invoke-WebRequest -Uri $fUrl -OutFile $fDest -UseBasicParsing -TimeoutSec 15
            } catch {
                Write-Warning "    Failed downloading $f from $fUrl"
            }
        }
    }
    
    # Link to ~/.claude/skills
    $destClaude = Join-Path $claudeSkillsDir $name
    if (-not (Test-Path $destClaude)) {
        try {
            New-Item -ItemType Junction -Path $destClaude -Target $destAgent -Force | Out-Null
        } catch {
            Copy-Item -Path "$destAgent\*" -Destination $destClaude -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "    ✅ Ready in ~/.agents/skills/$name" -ForegroundColor Green
}

# Install DSH Dynamic Preset for gemini-cli-router
if (Test-Path "$env:USERPROFILE\.dsh") {
    Write-Host "`n==> Configuring DeepSeek Harness Dynamic Presets..." -ForegroundColor Cyan
    $geminiPreset = Join-Path $dshPresetsDir "gemini-cli-router"
    if (-not (Test-Path $geminiPreset)) { New-Item -ItemType Directory -Path $geminiPreset -Force | Out-Null }
    
    $geminiAgent = Join-Path $agentsSkillsDir "gemini-cli-router"
    Copy-Item -Path (Join-Path $geminiAgent "plugin.js") -Destination $geminiPreset -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $geminiAgent "preset.yml") -Destination $geminiPreset -Force -ErrorAction SilentlyContinue
    Write-Host "    ✅ Configured DSH preset: gemini-cli-router" -ForegroundColor Green
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 🎉 INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "The following 5 skills are now active across your AI agents:" -ForegroundColor Cyan
Write-Host "  1. bell-notifier     -> Instant mobile push notifications via ntfy.sh & Discord"
Write-Host "  2. clipboard-context -> Direct OS clipboard & screenshot reader"
Write-Host "  3. git-checkpoint    -> 1-second git snapshot & instant rollback"
Write-Host "  4. quick-tunnel      -> Instant free Cloudflare HTTPS tunnel for any port"
Write-Host "  5. gemini-cli-router -> Ultra-fast Gemini 2.0 Flash delegation"
Write-Host ""
