import subprocess
from pathlib import Path

from encoding.helpers.encoding import nvenc_video_args
from encoding.helpers.tracks import get_audio_args, subtitle_args
from encoding.types.gpu_preset import GpuPreset

from .settings import SAMPLE_DURATION_SECONDS


def encode_sample(
    source: Path,
    output: Path,
    timestamp: str,
    cq: int,
    preset: GpuPreset,
) -> None:
    args = [
        "-y",
        "-hwaccel",
        "cuda",
        "-hwaccel_output_format",
        "cuda",
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
        *nvenc_video_args(cq, preset),
    ]
    args += get_audio_args(source) + subtitle_args(source) + [str(output)]
    print(f"\nEncoding sample: {output}")
    subprocess.run(["ffmpeg.exe", *args], check=True)
