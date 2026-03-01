#!/bin/bash
# Run Ralph to implement the audio chaptering tool stories from prd.json.
#
# Prerequisites:
#   1. Run ./plan.sh first to generate prd.json
#   2. claude CLI installed
#   3. ANTHROPIC_API_KEY exported
#
# Usage:
#   export ANTHROPIC_API_KEY=sk-ant-...
#   ./build.sh [max_sessions]

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_SH="$SCRIPT_DIR/ralph.sh"
RALPH_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)/ralph.sh"

# Check that planning was done first
if [ ! -f "$SCRIPT_DIR/prd.json" ]; then
  echo "Error: prd.json not found. Run ./plan.sh first to generate it."
  exit 1
fi

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

# Copy ralph.sh locally if not present (ralph.sh uses SCRIPT_DIR for file paths)
if [ ! -f "$RALPH_SH" ]; then
  if [ -f "$RALPH_SOURCE" ]; then
    cp "$RALPH_SOURCE" "$RALPH_SH"
    chmod +x "$RALPH_SH"
    echo "Copied ralph.sh from repo root."
  else
    echo "Error: ralph.sh not found at $RALPH_SOURCE"
    echo "Make sure this example is inside the ralph repo."
    exit 1
  fi
fi

MAX_SESSIONS="${1:-10}"

echo "============================================"
echo "  Audio Chaptering Tool — Build Phase"
echo "============================================"
echo ""

# Show what's about to be built
echo "Stories to implement:"
jq -r '.userStories[] | select(.passes == false) | "  [\(.id)] \(.title)"' "$SCRIPT_DIR/prd.json"
echo ""

"$RALPH_SH" --tool claude "$MAX_SESSIONS"
