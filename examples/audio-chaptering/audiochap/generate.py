"""Generate chapters from an uploaded audio file using Gemini."""

import json
import sys

from google import genai
from google.genai import types

MODEL = "gemini-2.0-flash"

CHAPTER_PROMPT = """\
Listen to this audio file and generate chapter markers.

Rules:
- Target chapter length: approximately {duration} minute(s)
- Force a chapter break at every {duration}-minute boundary even if the topic has not changed (hard time boundary)
- First chapter always starts at timestamp 0
- Each chapter title must be a concise, factual summary of the content discussed

Return ONLY a JSON array with no markdown formatting, no code blocks, no explanation. Format:
[
  {{"timestamp": <integer seconds>, "title": "<descriptive title>"}},
  ...
]"""


def generate_chapters(file_uri: str, api_key: str, duration_minutes: float) -> list[dict]:
    """Generate chapter markers from an uploaded audio file.

    Args:
        file_uri: File URI from Gemini File API.
        api_key: Gemini API key.
        duration_minutes: Target chapter length in minutes.

    Returns:
        List of chapter dicts with 'timestamp' (int seconds) and 'title' (str).

    Raises:
        SystemExit: On API errors or malformed response.
    """
    client = genai.Client(api_key=api_key)
    prompt = CHAPTER_PROMPT.format(duration=duration_minutes)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=[
                types.Part(file_data=types.FileData(file_uri=file_uri)),
                prompt,
            ],
        )
    except Exception as exc:
        print(f"Error: Gemini API call failed: {exc}", file=sys.stderr)
        sys.exit(1)

    return _parse_chapters(response.text)


def _parse_chapters(text: str) -> list[dict]:
    """Parse Gemini response text into a list of chapter dicts."""
    text = text.strip()
    # Strip markdown code fences if Gemini includes them despite instructions
    if text.startswith("```"):
        lines = text.splitlines()
        lines = [ln for ln in lines if not ln.startswith("```")]
        text = "\n".join(lines).strip()

    try:
        chapters = json.loads(text)
    except json.JSONDecodeError as exc:
        print(f"Error: Failed to parse Gemini response as JSON: {exc}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(chapters, list):
        print("Error: Gemini response is not a JSON array.", file=sys.stderr)
        sys.exit(1)

    if not chapters:
        print("Error: No chapters generated.", file=sys.stderr)
        sys.exit(1)

    validated = []
    for i, ch in enumerate(chapters):
        if not isinstance(ch, dict) or "timestamp" not in ch or "title" not in ch:
            print(
                f"Error: Chapter entry {i} missing required fields (timestamp, title).",
                file=sys.stderr,
            )
            sys.exit(1)
        try:
            timestamp = int(ch["timestamp"])
        except (TypeError, ValueError):
            print(
                f"Error: Chapter entry {i} has invalid timestamp: {ch['timestamp']}",
                file=sys.stderr,
            )
            sys.exit(1)
        validated.append({"timestamp": timestamp, "title": str(ch["title"])})

    return validated
