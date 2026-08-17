<#
.SYNOPSIS
  One-click setup: use the DeepSeek Harness GUI from your phone (iPhone / Android)
  through Tailscale - private and encrypted, nothing exposed to the public internet.

.DESCRIPTION
  This script:
    1. Installs Tailscale if it is missing (via winget) and logs you in if needed.
    2. Enables the Tailscale "Serve" feature for your tailnet (one click in the
       browser page it opens for you).
    3. Points your private tailnet address at the local harness GUI (port 3080).
    4. Restarts `dsh web` with --trusted-host so your phone can pass the harness
       /api trust fence.
    5. Prints the URL to open on your phone.

  Safe to re-run at any time. Only devices signed in to YOUR Tailscale account
  can reach the GUI. Your harness sessions are saved and survive the restart.

.NOTES
  Run with (PowerShell 5.1+ or PowerShell 7):
      irm https://raw.githubusercontent.com/1aifanatic/deepseek-harness-phone-access/main/setup-phone-access.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'DeepSeek Harness - phone access setup' } catch {}

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Magenta
Write-Host ' DeepSeek Harness on your phone, via Tailscale' -ForegroundColor Magenta
Write-Host ' (private + encrypted - nothing is exposed to the internet)' -ForegroundColor Magenta
Write-Host '============================================================' -ForegroundColor Magenta

# ---------------------------------------------------------------- 1. Tailscale
Write-Step 'Checking Tailscale...'
$tsCmd = $null
$ts = Get-Command tailscale -ErrorAction SilentlyContinue
if ($ts) {
    $tsCmd = $ts.Source
    Write-Ok "Tailscale found: $tsCmd"
} else {
    Write-Warn 'Tailscale is not installed. Installing it now via winget...'
    winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw 'Tailscale install failed. Install it from https://tailscale.com/download , then re-run this script.'
    }
    foreach ($candidate in @("$env:ProgramFiles\Tailscale\tailscale.exe", "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe")) {
        if (Test-Path $candidate) { $tsCmd = $candidate; break }
    }
    if (-not $tsCmd) { throw 'tailscale.exe was installed but not found on disk. Please log out/in of Windows and re-run.' }
    Write-Ok "Tailscale installed: $tsCmd"
}

# ---------------------------------------------------------------- 2. Login
Write-Step 'Checking Tailscale login...'
$statusJson = (& $tsCmd status --json 2>$null | Out-String)
if ($statusJson -notmatch '"BackendState"\s*:\s*"Running"') {
    Write-Warn 'You are not signed in to Tailscale yet. A browser will open - sign in'
    Write-Warn 'with the SAME account you will use on your phone, then press Enter here.'
    & $tsCmd up
    Start-Sleep -Seconds 5
}
$statusJson = (& $tsCmd status --json 2>$null | Out-String)
if ($statusJson -notmatch '"BackendState"\s*:\s*"Running"') {
    throw 'Tailscale is not running. Run `tailscale up`, finish the login, then re-run this script.'
}

# ---------------------------------------------------------------- 3. Tailnet name
Write-Step 'Resolving your tailnet address...'
$status = $statusJson | ConvertFrom-Json
$fqdn = "$($status.Self.DNSName)".TrimEnd('.')
if (-not $fqdn) {
    throw 'Could not read your tailnet name (MagicDNS may be off). Enable MagicDNS at https://login.tailscale.com/admin/dns and re-run.'
}
Write-Ok "Your private tailnet address: $fqdn"

# ---------------------------------------------------------------- 4. Enable Serve
Write-Step 'Checking Tailscale Serve...'
$serveStatus = (& $tsCmd serve status 2>&1 | Out-String)
if ($serveStatus -match 'Serve is not enabled') {
    $m = [regex]::Match($serveStatus, 'https://login\.tailscale\.com/f/serve\?node=[A-Za-z0-9_-]+')
    if ($m.Success) {
        Write-Warn 'Tailscale Serve is not enabled for your tailnet yet. I opened the enable page'
        Write-Warn 'in your browser - click the enable button there, then come back here.'
        Start-Process $m.Value
        Read-Host '    Press Enter after you have enabled Serve'
    } else {
        throw 'Tailscale Serve is not enabled and I could not open the enable page. Visit https://login.tailscale.com/admin/servers , enable Serve, and re-run.'
    }
} else {
    Write-Ok 'Tailscale Serve is available.'
}

# ---------------------------------------------------------------- 5. Point serve at the harness
Write-Step 'Pointing your tailnet address at the harness GUI (port 3080)...'
& $tsCmd serve --bg --yes 3080 2>&1 | Out-String | Write-Host
Start-Sleep -Seconds 2
$serveStatus = (& $tsCmd serve status 2>&1 | Out-String)
if ($serveStatus -notmatch 'proxy http://127\.0\.0\.1:3080') {
    throw 'Could not configure Tailscale Serve to forward to the harness. Re-run the script and check the output above.'
}
Write-Ok 'Tailscale Serve is now forwarding to 127.0.0.1:3080.'

# ---------------------------------------------------------------- 6. Restart dsh web with --trusted-host
Write-Step 'Restarting the harness with --trusted-host (sessions are saved)...'
$conn = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conn) {
    Write-Warn "Stopping the current harness (PID $($conn.OwningProcess)) so the new one can bind port 3080..."
    Stop-Process -Id $conn.OwningProcess -Force
    Start-Sleep -Seconds 2
}

$dshCmd = Get-Command dsh -ErrorAction SilentlyContinue
$npxCmd = Get-Command npx -ErrorAction SilentlyContinue
if ($dshCmd) {
    $inner = "dsh web --trusted-host $fqdn"
} elseif ($npxCmd) {
    Write-Warn "`dsh` was not found on PATH - starting via npx (the first start may take a moment)."
    $inner = "npx --yes @deepseek-ai/dsh web --trusted-host $fqdn"
} else {
    throw 'Could not find dsh or npx. Install the DeepSeek Harness CLI first, then re-run this script.'
}

Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $inner)
Write-Ok "Started: $inner"

$up = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://127.0.0.1:3080/'; if ($r.StatusCode -eq 200) { $up = $true; break } } catch {}
}
if ($up) { Write-Ok 'The harness is back up on http://127.0.0.1:3080 (refresh your browser).' }
else {
    Write-Warn 'The harness did not respond yet. Wait a few seconds, refresh http://127.0.0.1:3080,'
    Write-Warn "or start it yourself in a terminal with:  dsh web --trusted-host $fqdn"
}

# ---------------------------------------------------------------- 7. Verify
Write-Step 'Verifying phone access...'
$url = "https://${fqdn}/"
$page = '?'
$api = '?'
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
    $page = & curl.exe -sS --noproxy "*" -m 15 -o NUL -w "%{http_code}" $url 2>$null
    $api  = & curl.exe -sS --noproxy "*" -m 15 -o NUL -w "%{http_code}" -H "Origin: $url" "${url}api/health" 2>$null
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' DONE!' -ForegroundColor Green
Write-Host " Laptop GUI : http://127.0.0.1:3080   (refresh your browser)" -ForegroundColor Green
Write-Host " Phone URL  : $url" -ForegroundColor Green
Write-Host " Checks     : page=$page  api=$api   (200/404 = OK; 403 = not ready yet)" -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'On your phone:'
Write-Host '  1. Install the free "Tailscale" app (App Store / Play Store)'
Write-Host '  2. Sign in with the SAME account as this laptop'
Write-Host "  3. Open: $url"
Write-Host ''
Write-Host 'Daily use - start the harness with:'
Write-Host "    dsh web --trusted-host $fqdn"
Write-Host ''
Write-Host 'Undo (remove phone access):'
Write-Host '    tailscale serve reset'
Write-Host '    (then just run: dsh web)'
Write-Host ''
Write-Host 'Note: folder picker / settings / credentials stay laptop-only by design'
Write-Host '(they return 403 from the phone) - use them on the laptop instead.'
