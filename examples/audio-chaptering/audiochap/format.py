"""Output formatters for audiochap."""

import json


def format_json(chapters: list[dict]) -> str:
    """Format chapters as a JSON array.

    Each chapter has:
      - timestamp: int (seconds from start)
      - title: str (factual summary of chapter content)
    """
    return json.dumps(chapters, indent=2)


def _vtt_time(seconds: int) -> str:
    """Format seconds as HH:MM:SS.000 for WebVTT."""
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}.000"


def _srt_time(seconds: int) -> str:
    """Format seconds as HH:MM:SS,000 for SRT."""
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d},000"


def format_srt(chapters: list[dict], audio_duration: int | None = None) -> str:
    """Format chapters as an SRT file."""
    if not chapters:
        return ""

    lines = []

    for i, chapter in enumerate(chapters):
        start = chapter["timestamp"]
        if i + 1 < len(chapters):
            end = chapters[i + 1]["timestamp"]
        elif audio_duration is not None:
            end = audio_duration
        else:
            if len(chapters) > 1:
                avg_gap = (chapters[-1]["timestamp"] - chapters[0]["timestamp"]) // (len(chapters) - 1)
                end = chapters[-1]["timestamp"] + avg_gap
            else:
                end = chapters[0]["timestamp"] + 600

        lines.append(str(i + 1))
        lines.append(f"{_srt_time(start)} --> {_srt_time(end)}")
        lines.append(chapter["title"])
        lines.append("")

    return "\n".join(lines)


def format_vtt(chapters: list[dict], audio_duration: int | None = None) -> str:
    """Format chapters as a WebVTT chapter navigation file."""
    if not chapters:
        return "WEBVTT\n"

    lines = ["WEBVTT", ""]

    for i, chapter in enumerate(chapters):
        start = chapter["timestamp"]
        if i + 1 < len(chapters):
            end = chapters[i + 1]["timestamp"]
        elif audio_duration is not None:
            end = audio_duration
        else:
            # Estimate end of last chapter
            if len(chapters) > 1:
                avg_gap = (chapters[-1]["timestamp"] - chapters[0]["timestamp"]) // (len(chapters) - 1)
                end = chapters[-1]["timestamp"] + avg_gap
            else:
                end = chapters[0]["timestamp"] + 600  # 10 min default

        lines.append(f"{_vtt_time(start)} --> {_vtt_time(end)}")
        lines.append(chapter["title"])
        lines.append("")

    return "\n".join(lines)
