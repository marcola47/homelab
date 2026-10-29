from pathlib import Path

from .ffprobe_output import ffprobe_output


def get_video_duration_seconds(file_path: str | Path) -> float | None:
    try:
        value = ffprobe_output(
            [
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
            ],
            file_path,
        )

        return float(value) if value and value != "N/A" else None
    except OSError, ValueError, RuntimeError:
        return None
