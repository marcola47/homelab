import subprocess
from dataclasses import replace
from pathlib import Path

from encoding.helpers.media import get_video_duration_seconds
from encoding.types.gpu_preset import GPU_PRESETS
from encoding.types.sample_comparison import SampleComparison

from .compare_samples import compare_samples
from .safe_name import safe_name
from .sample_timestamps import sample_timestamps
from .settings import (
    QUALITY_TARGETS,
    SAMPLE_DURATION_SECONDS,
    VMAF_DEFAULT_MODEL,
    VMAF_NEG_MODEL,
)
from .vmaf_score import vmaf_score
from .write_preset_comparison_report import write_preset_comparison_report
from .write_vmaf_report import write_vmaf_report


def evaluate_source(source: Path, preset_selection: str) -> None:
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

    all_presets = preset_selection == "0"
    selected_presets = (
        [GPU_PRESETS[key] for key in ("3", "1", "2")]
        if all_presets
        else [GPU_PRESETS[preset_selection]]
    )
    aggregate: dict[str, dict[int, list[SampleComparison]]] = {}
    neg_comparisons: dict[int, list[SampleComparison]] = {}

    for preset in selected_presets:
        preset_results: dict[int, list[SampleComparison]] = {}
        preset_name = safe_name(preset.label.casefold().replace(" ", "_"))
        for quality in QUALITY_TARGETS:
            print(
                f"\nEvaluating {source.name}: {preset.label}, CQ {quality} "
                f"({len(timestamps)} samples)"
            )
            sample_directory = samples_directory / preset_name / f"cq_{quality}"
            sample_directory.mkdir(parents=True, exist_ok=True)
            use_neg = preset.label == "Film" and not all_presets
            comparisons = compare_samples(
                source,
                references,
                preset,
                quality,
                sample_directory,
                use_neg,
            )
            preset_results[quality] = comparisons
            if all_presets and preset.label == "Film":
                neg_samples: list[SampleComparison] = []
                for comparison, (_, reference) in zip(
                    comparisons, references, strict=True
                ):
                    sample_file = (
                        sample_directory / f"sample_{comparison.sample_number:02d}.mkv"
                    )
                    neg_mean, neg_p05 = vmaf_score(
                        reference, sample_file, use_neg_model=True
                    )
                    neg_samples.append(
                        replace(
                            comparison,
                            neg_mean=neg_mean,
                            neg_p05=neg_p05,
                        )
                    )
                neg_comparisons[quality] = neg_samples
            if not all_presets:
                report_path = samples_directory / (
                    f"vmaf_{preset_name}_cq_{quality}.md"
                )
                write_vmaf_report(
                    report_path,
                    source,
                    preset.label,
                    quality,
                    comparisons,
                    VMAF_NEG_MODEL if use_neg else VMAF_DEFAULT_MODEL,
                )
        aggregate[preset.label] = preset_results

    if all_presets:
        report_path = samples_directory / "preset_comparison.md"
        write_preset_comparison_report(report_path, source, aggregate, neg_comparisons)
        print(f"\nAggregate report written to: {report_path}")
    else:
        print(f"\nReports written to: {samples_directory}")
