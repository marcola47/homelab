import subprocess
from pathlib import Path

from encoding.helpers.encoding import get_cuda_rotation_filter, nvenc_video_args
from encoding.helpers.tracks import get_audio_args, subtitle_args

from .settings import SAMPLE_DURATION_SECONDS


def encode_sample(
    source: Path,
    output: Path,
    timestamp: str,
    cq: int,
) -> None:
    rotation_filter = get_cuda_rotation_filter(source)
    args = [
        "-y",
        "-hwaccel",
        "cuda",
        "-hwaccel_output_format",
        "cuda",
    ]

    if rotation_filter is not None:
        args.extend(["-display_rotation:v:0", "0"])

    args.extend(
        [
            "-noautorotate",
            "-ss",
            timestamp,
            "-t",
            str(SAMPLE_DURATION_SECONDS),
            "-i",
            str(source),
            "-map",
            "0:v:0",
            "-map",
            "0:a?",
        ]
    )

    if rotation_filter is not None:
        args.extend(["-vf", rotation_filter])

    args.extend(nvenc_video_args(cq))
    args += get_audio_args(source) + subtitle_args(source) + [str(output)]
    print(f"\nEncoding sample: {output}")
    subprocess.run(["ffmpeg.exe", *args], check=True)
