import subprocess
from pathlib import Path

from encoding.helpers.filesystem import safe_name
from encoding.helpers.media import get_video_duration_seconds
from encoding.types.sample_comparison import SampleComparison

from .compare_samples import compare_samples
from .sample_timestamps import sample_timestamps
from .settings import (
    QUALITY_TARGETS,
    SAMPLE_DURATION_SECONDS,
    VMAF_MODEL,
    VMAF_NEG_MODEL,
)
from .write_summary_report import write_summary_report
from .write_vmaf_report import write_vmaf_report


def evaluate_source(source: Path) -> None:
    duration = get_video_duration_seconds(source)

    if duration is None:
        raise RuntimeError(f"Could not determine video duration for '{source}'.")

    timestamps = sample_timestamps(duration)
    samples_directory = source.parent / "samples" / safe_name(source.stem)
    references_directory = samples_directory / "reference"
    references_directory.mkdir(parents=True, exist_ok=True)
    references: list[tuple[str, Path]] = []

    for index, timestamp in enumerate(timestamps, start=1):
        reference = references_directory / f"sample_{index:02d}.mkv"
        if not reference.is_file():
            subprocess.run(
                [
                    "ffmpeg.exe",
                    "-y",
                    "-ss",
                    timestamp,
                    "-i",
                    str(source),
                    "-t",
                    str(SAMPLE_DURATION_SECONDS),
                    "-map",
                    "0:v:0",
                    "-an",
                    "-sn",
                    "-dn",
                    "-c:v",
                    "ffv1",
                    str(reference),
                ],
                check=True,
            )
        references.append((timestamp, reference))

    comparisons_by_quality: dict[int, list[SampleComparison]] = {}
    for quality in QUALITY_TARGETS:
        print(f"\nEvaluating {source.name}: CQ {quality} ({len(timestamps)} samples)")
        sample_directory = samples_directory / f"cq_{quality}"
        sample_directory.mkdir(parents=True, exist_ok=True)
        comparisons = compare_samples(
            source,
            references,
            quality,
            sample_directory,
        )
        report_path = samples_directory / f"vmaf_cq_{quality}.md"

        write_vmaf_report(
            report_path,
            source,
            quality,
            comparisons,
        )
        comparisons_by_quality[quality] = comparisons

        print(
            f"Report written to: {report_path} (models: {VMAF_MODEL}, {VMAF_NEG_MODEL})"
        )

    summary_path = samples_directory / "vmaf_summary.md"
    write_summary_report(summary_path, source, comparisons_by_quality)
    print(f"Summary report written to: {summary_path}")
