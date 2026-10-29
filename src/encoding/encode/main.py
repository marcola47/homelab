import argparse
import re
import subprocess
import sys
from pathlib import Path

from encoding.helpers.encoding import ENCODING_PROFILE
from encoding.helpers.filesystem import get_video_files, resolve_dir, safe_name

from .add_bitrate_metadata import add_bitrate_metadata
from .ffmpeg_args import ffmpeg_args


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transcode videos to AV1 with Opus audio."
    )
    parser.add_argument("directory", nargs="?")
    args = parser.parse_args()
    directory = args.directory or input(
        "Enter directory path (or press Enter for current directory): "
    )

    try:
        root = resolve_dir(directory)
        assert root is not None

        cq_text = (
            input("Enter quality value (lower = better quality, default: 32): ").strip()
            or "32"
        )

        if not re.fullmatch(r"\d+", cq_text):
            raise ValueError(
                "Invalid quality value. Please enter only a whole number, e.g.: 32"
            )

        cq = int(cq_text)

        if not 0 <= cq <= 63:
            raise ValueError("NVENC CQ must be between 0 and 63.")

        print("\nStarting encoding process...")
        handled: set[Path] = set()

        while True:
            candidates = get_video_files(
                root,
                (".mkv", ".mp4", ".avi"),
                exclude_patterns=(r"[\\/]+encoded[\\/]",),
            )
            source = next(
                (item for item in candidates if item.resolve() not in handled), None
            )

            if source is None:
                break

            if not source.is_file():
                print(f"WARNING: File not found: {source}")
                continue

            sanitized_source_name = safe_name(source.name)

            if sanitized_source_name != source.name:
                target = source.with_name(sanitized_source_name)

                if target.exists() and target != source:
                    raise FileExistsError(
                        f"Cannot rename '{source}' because '{target}' already exists."
                    )

                source.rename(target)
                source = target.resolve()
            else:
                source = source.resolve()

            handled.add(source.resolve())
            output_dir = source.parent / "encoded"
            output_dir.mkdir(parents=True, exist_ok=True)
            output = output_dir / f"{safe_name(source.stem)}.mkv"

            if output.is_file():
                print(f"Skipping existing output: {output}")
                continue

            print(f"Starting: {source}\nOutput:   {output}")
            print(f"Audio: Opus 128k VBR stereo; CQ: {cq}")
            print(f"Profile: {ENCODING_PROFILE} | GOP 240")

            code = subprocess.run(
                ["ffmpeg.exe", *ffmpeg_args(source, output, cq)]
            ).returncode

            if code:
                raise RuntimeError(
                    f"ffmpeg failed with exit code {code} while processing '{source}'."
                )

            if not output.is_file():
                print(f"WARNING: Output file not found after encode: {output}")
                continue

            probe = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-show_entries",
                    "format=duration",
                    "-of",
                    "default=noprint_wrappers=1:nokey=1",
                    str(output),
                ],
                capture_output=True,
                text=True,
            )

            if probe.returncode:
                raise RuntimeError(
                    f"ffprobe failed with exit code {probe.returncode} for '{output}': "
                    f"{probe.stderr.strip()}"
                )

            try:
                duration = float(probe.stdout.strip())
            except ValueError as error:
                raise RuntimeError(
                    f"ffprobe returned an invalid duration for '{output}': "
                    f"{probe.stdout.strip()!r}"
                ) from error

            if duration <= 0:
                raise RuntimeError(
                    f"ffprobe returned a non-positive duration for '{output}'."
                )

            bitrate_bps = round(output.stat().st_size * 8 / duration)

            add_bitrate_metadata(output, bitrate_bps)
            print(f"Embedded bitrate metadata: {bitrate_bps // 1000} kbps")

        print("All files processed successfully!")
    except Exception as error:
        print(f"\nFATAL ERROR: {error}")
        return 1
    finally:
        if sys.stdin.isatty():
            input("Press Enter to close...")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
