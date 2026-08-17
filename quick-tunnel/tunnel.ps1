param(
    [Parameter(Position = 0)]
    [int]$Port = 3000,

    [Parameter()]
    [switch]$Background,

    [Parameter()]
    [switch]$KillAll
)

$toolsDir = "$env:USERPROFILE\.config\agent-tools"
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}

$cloudflaredPath = Join-Path $toolsDir "cloudflared.exe"

if ($KillAll) {
    Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Output "All tunnel processes stopped."
    exit 0
}

# 1. Check if cloudflared is on PATH or in toolsDir
if (-not (Get-Command "cloudflared" -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path $cloudflaredPath)) {
        Write-Output "Downloading standalone cloudflared binary (free zero-login tunnel)..."
        $cfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        try {
            Invoke-WebRequest -Uri $cfUrl -OutFile $cloudflaredPath -UseBasicParsing -TimeoutSec 30
            Write-Output "Downloaded cloudflared to $cloudflaredPath"
        } catch {
            Write-Error "Failed to download cloudflared: $_"
            exit 1
        }
    }
    $cfExe = $cloudflaredPath
} else {
    $cfExe = "cloudflared"
}

Write-Output "Starting Cloudflare Quick Tunnel on port $Port (http://localhost:$Port)..."
Write-Output "Zero configuration required. Free temporary HTTPS URL will be generated."

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $cfExe
$psi.Arguments = "tunnel --url http://localhost:$Port"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)

$publicUrl = $null
$timeout = [DateTime]::Now.AddSeconds(20)

while ([DateTime]::Now -lt $timeout) {
    $line = $proc.StandardError.ReadLine()
    if ($line -match "(https://[a-zA-Z0-9-]+\.trycloudflare\.com)") {
        $publicUrl = $matches[1]
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($publicUrl) {
    Write-Output "`n======================================================="
    Write-Output "  🚀 PUBLIC TUNNEL URL: $publicUrl"
    Write-Output "  Pointing to: http://localhost:$Port"
    Write-Output "=======================================================`n"
    
    if (-not $Background) {
        Write-Output "Tunnel running in background (PID: $($proc.Id)). Run 'tunnel.ps1 -KillAll' to stop."
    }
} else {
    Write-Warning "Tunnel started (PID $($proc.Id)), but URL capture timed out. Check output logs."
}
