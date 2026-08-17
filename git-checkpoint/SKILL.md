---
name: git-checkpoint
description: Create a 1-second instant git snapshot of all staged and unstaged work before attempting risky refactors, tests, or changes, with one-command instant rollback. Use when the user asks to "make a checkpoint", "save a snapshot", "backup state before editing", "undo my agent's last changes", or "rollback to checkpoint".
---

# Git Checkpoint (`/checkpoint`)

Provides 1-second zero-overhead git snapshots and instant rollbacks for agent sessions without altering working branches or pushing commits.

## When to Use

- **Pre-flight safety**: Always save a checkpoint before starting complex refactors, destructive file reorganizations, or unfamiliar dependency migrations.
- **Instant Rollback**: When a test run fails catastrophically or an agent makes unwanted edits, restore the exact working state in 1 second.
- **Inspect Diffs**: Check the diff between current work and the last checkpoint.

## Commands

Execute via PowerShell in any git repository:

### 1. Save a Checkpoint
```powershell
pwsh -File "<skill-dir>/checkpoint.ps1" save "before-auth-refactor"
```
*(If no name is passed, creates an automatic timestamped checkpoint like `checkpoint-20260817-154500`)*

### 2. Rollback to Checkpoint
```powershell
pwsh -File "<skill-dir>/checkpoint.ps1" rollback "before-auth-refactor"
```
*(If no name is provided, rolls back to the most recent checkpoint)*

### 3. List All Checkpoints
```powershell
pwsh -File "<skill-dir>/checkpoint.ps1" list
```

### 4. View Diff Against Checkpoint
```powershell
pwsh -File "<skill-dir>/checkpoint.ps1" diff
```
