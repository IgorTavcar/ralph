"""audiochap CLI entry point."""

import argparse
import os
import sys
from pathlib import Path

from audiochap.format import format_json, format_srt, format_vtt
from audiochap.generate import generate_chapters
from audiochap.upload import upload_audio

SUPPORTED_AUDIO_EXTENSIONS = {".mp3", ".wav", ".m4a", ".ogg", ".flac"}


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        print(f"Error: {message}", file=sys.stderr)
        self.print_usage(sys.stderr)
        sys.exit(1)


def parse_args(argv=None):
    parser = _Parser(
        prog="audiochap",
        description="Generate chapter markers for audio files using Gemini multimodal API.",
    )
    parser.add_argument(
        "input",
        metavar="INPUT",
        help="Path to the audio file (mp3, wav, m4a, ogg, flac)",
    )
    parser.add_argument(
        "--format",
        choices=["json", "vtt", "srt"],
        default="json",
        help="Output format: json (default), vtt, or srt",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=10,
        metavar="N",
        help="Target chapter length in minutes (default: 10)",
    )
    parser.add_argument(
        "--output",
        metavar="FILE",
        default=None,
        help="Output file path (default: stdout)",
    )
    return parser.parse_args(argv)


def validate_args(args):
    """Validate parsed arguments. Prints to stderr and exits on error."""
    # Validate GEMINI_API_KEY
    if not os.environ.get("GEMINI_API_KEY"):
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    # Validate input file exists
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    if not input_path.is_file():
        print(f"Error: Input path is not a file: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Validate audio extension
    if input_path.suffix.lower() not in SUPPORTED_AUDIO_EXTENSIONS:
        supported = ", ".join(sorted(SUPPORTED_AUDIO_EXTENSIONS))
        print(
            f"Error: Unsupported audio format '{input_path.suffix}'. "
            f"Supported formats: {supported}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Validate duration is positive
    if args.duration <= 0:
        print("Error: --duration must be a positive number.", file=sys.stderr)
        sys.exit(1)


def main(argv=None):
    args = parse_args(argv)
    validate_args(args)

    api_key = os.environ["GEMINI_API_KEY"]
    file_uri = upload_audio(args.input, api_key)
    chapters = generate_chapters(file_uri, api_key, args.duration)

    if args.format == "json":
        output = format_json(chapters)
    elif args.format == "vtt":
        output = format_vtt(chapters)
    elif args.format == "srt":
        output = format_srt(chapters)
    else:
        print(f"Error: Format '{args.format}' is not yet implemented.", file=sys.stderr)
        sys.exit(1)

    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
    else:
        print(output)


if __name__ == "__main__":
    main()
