"""Upload audio files to Gemini File API."""

import sys
from pathlib import Path

from google import genai

MIME_TYPES = {
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".m4a": "audio/mp4",
    ".ogg": "audio/ogg",
    ".flac": "audio/flac",
}


def upload_audio(file_path: str | Path, api_key: str) -> str:
    """Upload an audio file to Gemini File API and return the file URI.

    Args:
        file_path: Path to the audio file.
        api_key: Gemini API key.

    Returns:
        The file URI string for use in subsequent Gemini API calls.

    Raises:
        SystemExit: On upload failure (network, auth, invalid file).
    """
    path = Path(file_path)
    mime_type = MIME_TYPES.get(path.suffix.lower())
    if mime_type is None:
        print(f"Error: Unsupported audio format '{path.suffix}'.", file=sys.stderr)
        sys.exit(1)

    try:
        client = genai.Client(api_key=api_key)
        uploaded = client.files.upload(
            file=path,
            config={"mime_type": mime_type},
        )
    except Exception as exc:
        print(f"Error: Failed to upload audio file: {exc}", file=sys.stderr)
        sys.exit(1)

    return uploaded.uri
