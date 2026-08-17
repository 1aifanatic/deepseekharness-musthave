#!/usr/bin/env bash
# Universal Installer for Must-Have AI Agent Skills (macOS & Linux)
# =================================================================
set -euo pipefail

echo -e "\n============================================================"
echo -e " 🚀 Installing DeepSeek Harness Must-Have Suite"
echo -e "============================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "$PWD")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
DSH_PRESETS_DIR="$HOME/.dsh/.agent-presets"

mkdir -p "$AGENTS_DIR"
mkdir -p "$CLAUDE_DIR"

SKILL_NAMES=(
  "bell-notifier"
  "clipboard-context"
  "git-checkpoint"
  "quick-tunnel"
  "gemini-cli-router"
)

RAW_BASE_URL="https://raw.githubusercontent.com/1aifanatic/deepseekharness-musthave/main"

for skill_name in "${SKILL_NAMES[@]}"; do
  echo -e "\n==> Installing $skill_name..."
  target_agent="$AGENTS_DIR/$skill_name"
  target_claude="$CLAUDE_DIR/$skill_name"
  mkdir -p "$target_agent"

  local_dir="$REPO_ROOT/$skill_name"
  if [ -d "$local_dir" ]; then
    cp -r "$local_dir"/* "$target_agent/"
  else
    echo "    Downloading $skill_name from GitHub..."
    case "$skill_name" in
      "bell-notifier")
        curl -fsSL "$RAW_BASE_URL/$skill_name/SKILL.md" -o "$target_agent/SKILL.md" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/notify.ps1" -o "$target_agent/notify.ps1" || true
        ;;
      "clipboard-context")
        curl -fsSL "$RAW_BASE_URL/$skill_name/SKILL.md" -o "$target_agent/SKILL.md" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/grab-clip.ps1" -o "$target_agent/grab-clip.ps1" || true
        ;;
      "git-checkpoint")
        curl -fsSL "$RAW_BASE_URL/$skill_name/SKILL.md" -o "$target_agent/SKILL.md" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/checkpoint.ps1" -o "$target_agent/checkpoint.ps1" || true
        ;;
      "quick-tunnel")
        curl -fsSL "$RAW_BASE_URL/$skill_name/SKILL.md" -o "$target_agent/SKILL.md" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/tunnel.ps1" -o "$target_agent/tunnel.ps1" || true
        ;;
      "gemini-cli-router")
        curl -fsSL "$RAW_BASE_URL/$skill_name/SKILL.md" -o "$target_agent/SKILL.md" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/gemini-run.ps1" -o "$target_agent/gemini-run.ps1" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/plugin.js" -o "$target_agent/plugin.js" || true
        curl -fsSL "$RAW_BASE_URL/$skill_name/preset.yml" -o "$target_agent/preset.yml" || true
        ;;
    esac
  fi

  if [ ! -e "$target_claude" ]; then
    ln -s "$target_agent" "$target_claude" 2>/dev/null || cp -r "$target_agent"/* "$target_claude/" 2>/dev/null || true
  fi

  echo "    ✅ Ready in ~/.agents/skills/$skill_name"
done

if [ -d "$HOME/.dsh" ]; then
  mkdir -p "$DSH_PRESETS_DIR/gemini-cli-router"
  cp "$AGENTS_DIR/gemini-cli-router/plugin.js" "$DSH_PRESETS_DIR/gemini-cli-router/" 2>/dev/null || true
  cp "$AGENTS_DIR/gemini-cli-router/preset.yml" "$DSH_PRESETS_DIR/gemini-cli-router/" 2>/dev/null || true
  echo -e "\n  ✅ Configured DeepSeek Harness preset: gemini-cli-router"
fi

echo -e "\n============================================================"
echo -e " 🎉 INSTALLATION COMPLETE"
echo -e "============================================================"
echo -e "Active across DeepSeek Harness, Claude Code, Codex, and Cursor.\n"
