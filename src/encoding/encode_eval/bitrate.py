from pathlib import Path

from encoding.helpers.media import get_video_duration_seconds


def bitrate(file: Path) -> int:
    duration = get_video_duration_seconds(file)

    if duration is None or duration <= 0:
        raise RuntimeError(f"Could not determine a valid duration for '{file}'.")

    return round(file.stat().st_size * 8 / duration)
