import subprocess
from collections.abc import Iterable
from pathlib import Path


def ffprobe_output(args: Iterable[str], file_path: str | Path) -> str:
    result = subprocess.run(
        ["ffprobe", *args, "--", str(file_path)],
        text=True,
        capture_output=True,
    )

    if result.returncode:
        raise RuntimeError(
            result.stderr.strip() or f"ffprobe exited with {result.returncode}"
        )

    return result.stdout.strip()
