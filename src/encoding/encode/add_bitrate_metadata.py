import subprocess
from pathlib import Path


def add_bitrate_metadata(output: Path, bitrate_bps: int) -> None:
    bitrate_kbps = bitrate_bps // 1000
    metadata_value = f"{bitrate_kbps} kbps"
    tagged_output = output.with_name(f"{output.stem}.metadata.tmp.mkv")

    try:
        result = subprocess.run(
            [
                "ffmpeg.exe",
                "-y",
                "-i",
                str(output),
                "-map",
                "0",
                "-map_metadata",
                "0",
                "-map_chapters",
                "0",
                "-c",
                "copy",
                "-metadata",
                f"ENCODED_BITRATE={metadata_value}",
                str(tagged_output),
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode:
            raise RuntimeError(
                f"Could not add bitrate metadata to '{output}': {result.stderr.strip()}"
            )

        probe = subprocess.run(
            [
                "ffprobe.exe",
                "-v",
                "error",
                "-show_entries",
                "format_tags=ENCODED_BITRATE",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(tagged_output),
            ],
            capture_output=True,
            text=True,
        )

        if probe.returncode:
            raise RuntimeError(
                f"Could not verify bitrate metadata in '{tagged_output}': "
                f"{probe.stderr.strip()}"
            )

        if probe.stdout.strip() != metadata_value:
            raise RuntimeError(
                f"Bitrate metadata verification failed for '{tagged_output}'."
            )

        tagged_output.replace(output)
    finally:
        if tagged_output.exists():
            tagged_output.unlink()
