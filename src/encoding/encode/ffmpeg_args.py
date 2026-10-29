from pathlib import Path

from encoding.helpers.encoding import nvenc_video_args
from encoding.helpers.tracks import get_audio_args, subtitle_args
from encoding.types.gpu_preset import GpuPreset


def ffmpeg_args(
    source: Path,
    output: Path,
    cq: int,
    preset: GpuPreset,
) -> list[str]:
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
        *nvenc_video_args(cq, preset),
    ]

    return args + get_audio_args(source) + subtitle_args(source) + [str(output)]
