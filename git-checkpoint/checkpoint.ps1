param(
    [Parameter(Position = 0)]
    [ValidateSet("save", "rollback", "list", "diff", "clear")]
    [string]$Action = "save",

    [Parameter(Position = 1)]
    [string]$Name
)

$ErrorActionPreference = "Stop"

# Ensure we are in a git repository
try {
    $repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
} catch {
    Write-Error "Not inside a git repository."
    exit 1
}

$checkpointDir = Join-Path $repoRoot ".git/checkpoints"
if (-not (Test-Path $checkpointDir)) {
    New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
}

$indexFile = Join-Path $checkpointDir "index.json"
$records = @()
if (Test-Path $indexFile) {
    try {
        $records = Get-Content $indexFile -Raw | ConvertFrom-Json
        if ($records -isnot [array]) { $records = @($records) }
    } catch {
        $records = @()
    }
}

switch ($Action) {
    "save" {
        $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $tag = if ($Name) { $Name } else { "checkpoint-$timestamp" }
        
        # Capture current dirty state via git stash create without modifying worktree
        $stashOutput = git stash create "Checkpoint: $tag" 2>$null
        $stashCommit = if ($stashOutput) { $stashOutput.ToString().Trim() } else { $null }
        $headOutput = git rev-parse HEAD 2>$null
        $headCommit = if ($headOutput) { $headOutput.ToString().Trim() } else { "" }
        
        $targetCommit = if ($stashCommit) { $stashCommit } else { $headCommit }
        
        $newRecord = [PSCustomObject]@{
            id = $tag
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            commit = $targetCommit
            head = $headCommit
            hasUncommittedChanges = [bool]$stashCommit
        }
        
        # Store ref
        git update-ref "refs/checkpoints/$tag" $targetCommit
        
        $records = @($newRecord) + ($records | Where-Object { $_.id -ne $tag })
        $records | ConvertTo-Json -Depth 3 | Set-Content $indexFile -Force
        
        Write-Output "Checkpoint '$tag' saved at $targetCommit."
        Write-Output "To rollback later: checkpoint rollback '$tag'"
    }

    "rollback" {
        if (-not $Name -and $records.Count -gt 0) {
            $Name = $records[0].id
        }
        if (-not $Name) {
            Write-Error "No checkpoint specified and no recent checkpoint found."
            exit 1
        }
        
        $target = $records | Where-Object { $_.id -eq $Name } | Select-Object -First 1
        if (-not $target) {
            Write-Error "Checkpoint '$Name' not found."
            exit 1
        }
        
        # Stash current dirty work as safety backup before rolling back
        $safetyOutput = git stash create "Pre-rollback safety backup" 2>$null
        $safety = if ($safetyOutput) { $safetyOutput.ToString().Trim() } else { $null }
        if ($safety) {
            git update-ref "refs/checkpoints/safety-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" $safety
        }
        
        # Reset to the checkpoint state
        if ($target.hasUncommittedChanges) {
            # Stash commit contains worktree + index
            git reset --hard $target.head
            git stash apply $target.commit 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # Fallback to checkout
                git checkout -f $target.commit -- .
            }
        } else {
            git reset --hard $target.head
        }
        
        Write-Output "Successfully rolled back workspace to checkpoint '$Name' ($($target.timestamp))."
    }

    "list" {
        if ($records.Count -eq 0) {
            Write-Output "No checkpoints saved."
            exit 0
        }
        Write-Output "=== Git Checkpoints ==="
        $records | Select-Object id, timestamp, commit, hasUncommittedChanges | Format-Table -AutoSize
    }

    "diff" {
        $targetId = if ($Name) { $Name } else { if ($records.Count -gt 0) { $records[0].id } }
        if (-not $targetId) {
            Write-Error "No checkpoint to diff against."
            exit 1
        }
        $target = $records | Where-Object { $_.id -eq $targetId } | Select-Object -First 1
        if ($target) {
            git diff $target.commit
        }
    }

    "clear" {
        Remove-Item $checkpointDir -Recurse -Force -ErrorAction SilentlyContinue
        git for-each-ref --format="%(refname)" refs/checkpoints/ | ForEach-Object {
            git update-ref -d $_
        }
        Write-Output "All checkpoints cleared."
    }
}
