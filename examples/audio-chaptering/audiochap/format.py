"""Output formatters for audiochap."""

import json


def format_json(chapters: list[dict]) -> str:
    """Format chapters as a JSON array.

    Each chapter has:
      - timestamp: int (seconds from start)
      - title: str (factual summary of chapter content)
    """
    return json.dumps(chapters, indent=2)
