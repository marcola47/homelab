from pathlib import Path

from encoding.helpers.encoding import nvenc_video_args
from encoding.helpers.tracks import get_audio_args, subtitle_args


def ffmpeg_args(source: Path, output: Path, cq: int) -> list[str]:
    args = [
        "-y",
        "-hwaccel",
        "cuda",
        "-hwaccel_output_format",
        "cuda",
        "-i",
        str(source),
        "-map",
        "0:v:0",
        "-map",
        "0:a?",
        *nvenc_video_args(cq),
    ]

    return args + get_audio_args(source) + subtitle_args(source) + [str(output)]
