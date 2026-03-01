#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude|codex] [--retries N] [--hang-timeout N] [max_iterations]

set -e
set -o pipefail

# Parse arguments
TOOL="amp"  # Default to amp for backwards compatibility
MAX_ITERATIONS=10
MAX_RETRIES=3
HANG_TIMEOUT=5  # Seconds to wait after result before killing hung process

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --retries)
      MAX_RETRIES="$2"
      shift 2
      ;;
    --retries=*)
      MAX_RETRIES="${1#*=}"
      shift
      ;;
    --hang-timeout)
      HANG_TIMEOUT="$2"
      shift 2
      ;;
    --hang-timeout=*)
      HANG_TIMEOUT="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "codex" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'codex'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || { echo "Error: Cannot determine script directory"; exit 1; }
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
HINTS_FILE="$SCRIPT_DIR/.ralph-hints.txt"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME="${LAST_BRANCH#ralph/}"
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    if ! mkdir -p "$ARCHIVE_FOLDER"; then
      echo "Error: Failed to create archive folder: $ARCHIVE_FOLDER"
      exit 1
    fi
    [ -f "$PRD_FILE" ] && { cp "$PRD_FILE" "$ARCHIVE_FOLDER/" || echo "Warning: Failed to archive prd.json"; }
    [ -f "$PROGRESS_FILE" ] && { cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/" || echo "Warning: Failed to archive progress.txt"; }
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS - Max retries: $MAX_RETRIES - Hang timeout: $HANG_TIMEOUT"

# Validate required tools are available
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

if [[ "$TOOL" == "amp" ]] && ! command -v amp &>/dev/null; then
  echo "Error: amp is required but not installed."
  exit 1
fi

if [[ "$TOOL" == "claude" ]] && ! command -v claude &>/dev/null; then
  echo "Error: claude is required but not installed."
  exit 1
fi

if [[ "$TOOL" == "codex" ]] && ! command -v codex &>/dev/null; then
  echo "Error: codex is required but not installed."
  exit 1
fi

# Retry configuration
INITIAL_RETRY_DELAY=5

# Temp file for stream output (cleaned up on exit)
STREAM_OUTPUT=$(mktemp)
trap "rm -f $STREAM_OUTPUT" EXIT

# Function to check if output contains a retryable error
is_retryable_error() {
  local output="$1"
  if echo "$output" | grep -qE "No messages returned|ECONNRESET|ETIMEDOUT|rate limit|503|502|504|overloaded"; then
    return 0
  fi
  return 1
}

# Function to run Claude with stream-json and hang detection
# This fixes the issue where Claude completes work but hangs during exit/cleanup
run_claude_with_stream() {
  local prompt_file="$1"
  local hints="$2"
  local prompt_content
  if [ -n "$hints" ]; then
    prompt_content=$(printf '%s\n\n---\n\n%s' "$hints" "$(<"$prompt_file")")
  else
    prompt_content=$(<"$prompt_file")
  fi

  # Clear the output file
  : > "$STREAM_OUTPUT"

  # Run Claude with stream-json output in background
  claude --dangerously-skip-permissions -p "$prompt_content" --output-format stream-json --verbose 2>&1 > "$STREAM_OUTPUT" &
  local claude_pid=$!

  local result_received=false
  local killer_pid=""

  # Monitor the output file for the result message
  # The key insight: "type":"result" is emitted BEFORE the hang occurs
  while kill -0 $claude_pid 2>/dev/null; do
    if grep -q '"type":"result"' "$STREAM_OUTPUT" 2>/dev/null; then
      result_received=true
      echo "✓ Result received, waiting ${HANG_TIMEOUT}s for clean exit..."

      # Give Claude time to exit gracefully, then kill if hung
      ( sleep $HANG_TIMEOUT; kill $claude_pid 2>/dev/null ) &
      killer_pid=$!
      break
    fi
    sleep 0.5
  done

  # Wait for Claude to finish (or be killed)
  wait $claude_pid 2>/dev/null || true

  # Clean up the killer process if it's still running
  if [ -n "$killer_pid" ]; then
    kill $killer_pid 2>/dev/null || true
  fi

  # Extract the result text from stream-json output
  local result_text=""
  if [ "$result_received" = true ]; then
    result_text=$(grep '"type":"result"' "$STREAM_OUTPUT" | jq -r '.result // empty' 2>/dev/null | head -1)

    if [ -n "$result_text" ]; then
      echo "$result_text"
      return 0
    fi
  fi

  # If no result was extracted, return the raw output
  cat "$STREAM_OUTPUT"

  if [ "$result_received" = true ]; then
    return 0
  else
    return 1
  fi
}

# Function to run the tool with retries
# Usage: run_with_retry [hints]
run_with_retry() {
  local hints="$1"
  local attempt=1
  local delay=$INITIAL_RETRY_DELAY
  local output=""
  local exit_code=0

  while [ $attempt -le $MAX_RETRIES ]; do
    if [ $attempt -gt 1 ]; then
      echo "Retry attempt $attempt of $MAX_RETRIES (waiting ${delay}s)..."
      sleep $delay
      delay=$((delay * 2))  # Exponential backoff
    fi

    # Run the selected tool
    if [[ "$TOOL" == "amp" ]]; then
      if [ -n "$hints" ]; then
        output=$( (printf '%s\n\n' "$hints"; cat "$SCRIPT_DIR/prompt.md") | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || exit_code=$?
      else
        output=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || exit_code=$?
      fi
    elif [[ "$TOOL" == "claude" ]]; then
      # Use stream-json approach for Claude to avoid hang issues
      output=$(run_claude_with_stream "$SCRIPT_DIR/CLAUDE.md" "$hints" 2>&1 | tee /dev/stderr) || exit_code=$?
    else
      # Codex
      if [ -n "$hints" ]; then
        PROMPT_CONTENT=$(printf '%s\n\n%s' "$hints" "$(cat "$SCRIPT_DIR/prompt.md")")
      else
        PROMPT_CONTENT="$(cat "$SCRIPT_DIR/prompt.md")"
      fi
      output=$(codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT_CONTENT" 2>&1 | tee /dev/stderr) || exit_code=$?
    fi

    # Check if we got a retryable error
    if is_retryable_error "$output"; then
      echo ""
      echo "⚠ Detected transient error, will retry..."
      attempt=$((attempt + 1))
      continue
    fi

    # Success or non-retryable error - return the output
    echo "$output"
    return 0
  done

  # All retries exhausted
  echo ""
  echo "✗ All $MAX_RETRIES retry attempts failed"
  echo "$output"
  return 1
}

check_prd_completion() {
  local remaining_stories

  if [ ! -f "$PRD_FILE" ]; then
    echo "Warning: Missing PRD file at $PRD_FILE. Treating as incomplete."
    return 1
  fi

  if ! remaining_stories="$(jq '.userStories[] | select(.passes == false) | {id, title, passes}' "$PRD_FILE" 2>/dev/null)"; then
    echo "Warning: Unable to parse $PRD_FILE for completion check. Treating as incomplete."
    return 1
  fi

  [ -z "$remaining_stories" ]
}

# Track consecutive errors
ERROR_COUNT=0
MAX_CONSECUTIVE_ERRORS=3

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="

  # Extract current user story (highest priority with passes: false)
  STORY_TITLE=""
  STORY_DESC=""
  if [ -f "$PRD_FILE" ]; then
    STORY_TITLE=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].title // empty' "$PRD_FILE" 2>/dev/null || echo "")
    STORY_DESC=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].description // empty' "$PRD_FILE" 2>/dev/null || echo "")
  fi

  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  if [ -n "$STORY_TITLE" ]; then
    echo "  Story: $STORY_TITLE"
    [ -n "$STORY_DESC" ] && echo "  $STORY_DESC"
  fi
  echo "==============================================================="

  # Check for user hints file and prepend to prompt if present
  HINTS=""
  if [ -f "$HINTS_FILE" ]; then
    # Atomic read-and-delete: rename first, then read
    HINTS_CONSUMED="${HINTS_FILE}.consumed"
    if mv "$HINTS_FILE" "$HINTS_CONSUMED" 2>/dev/null; then
      HINTS=$(cat "$HINTS_CONSUMED")
      rm -f "$HINTS_CONSUMED"
      echo "📌 Applying user hints to this iteration"
    fi
  fi

  # Run the tool with automatic retry on transient errors
  OUTPUT=$(run_with_retry "$HINTS") || true

  # Track consecutive errors
  if [ -z "$OUTPUT" ] || [ "${#OUTPUT}" -lt 50 ]; then
    ERROR_COUNT=$((ERROR_COUNT + 1))
    echo "⚠️  Warning: $TOOL returned minimal output (error $ERROR_COUNT of $MAX_CONSECUTIVE_ERRORS)"

    if [ "$ERROR_COUNT" -ge "$MAX_CONSECUTIVE_ERRORS" ]; then
      echo "❌ Error: $MAX_CONSECUTIVE_ERRORS consecutive minimal outputs. Stopping."
      exit 1
    fi
  else
    ERROR_COUNT=0
  fi

  # Check completion based on PRD stories.
  if check_prd_completion; then
    echo ""
    echo "✅ Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
