#!/bin/bash
# Plan the audio chaptering tool by interviewing the user via ask_user_questions MCP.
#
# Prerequisites:
#   1. bun installed (https://bun.sh)
#   2. claude CLI installed (npm install -g @anthropic-ai/claude-code)
#   3. ANTHROPIC_API_KEY exported
#
# Usage:
#   export ANTHROPIC_API_KEY=sk-ant-...
#   ./plan.sh
#
# In a SECOND terminal, start the AUQ answer UI:
#   bunx -y auq-mcp-server
#
# Claude will ask you questions in the AUQ TUI. Answer them there.
# After all rounds, Claude writes the PRD and prd.json.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate environment
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: ANTHROPIC_API_KEY is not set."
  echo "  export ANTHROPIC_API_KEY=sk-ant-..."
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

if ! command -v bun &>/dev/null && ! command -v bunx &>/dev/null; then
  echo "Error: bun not found. Install from https://bun.sh"
  exit 1
fi

# Create output directories
mkdir -p "$SCRIPT_DIR/tasks"

echo "============================================"
echo "  Audio Chaptering Tool — PRD Planning"
echo "============================================"
echo ""
echo "Claude will interview you using the ask_user_questions MCP tool."
echo ""
echo "  IMPORTANT: Open a second terminal and run:"
echo "    bunx -y auq-mcp-server"
echo ""
echo "  That's where you'll answer the questions."
echo ""
echo "Press Enter when your AUQ terminal is ready..."
read -r

echo "Starting planning session..."
echo ""

cd "$SCRIPT_DIR"
claude --dangerously-skip-permissions -p "Read PLAN.md and follow the instructions. Interview me thoroughly using ask_user_questions, then write the PRD and prd.json."
