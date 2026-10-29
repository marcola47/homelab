from pathlib import Path

from encoding.types.gpu_preset import GpuPreset
from encoding.types.sample_comparison import SampleComparison

from .bitrate import bitrate
from .encode_sample import encode_sample
from .settings import SAMPLE_COUNT
from .vmaf_score import vmaf_score


def compare_samples(
    source: Path,
    references: list[tuple[str, Path]],
    preset: GpuPreset,
    quality: int,
    output_directory: Path,
    use_neg_model: bool,
) -> list[SampleComparison]:
    comparisons: list[SampleComparison] = []
    for sample_number, (timestamp, reference) in enumerate(references, start=1):
        output = output_directory / f"sample_{sample_number:02d}.mkv"
        encode_sample(source, output, timestamp, quality, preset)

        mean_score, p05_score = vmaf_score(
            reference, output, use_neg_model=use_neg_model
        )
        comparisons.append(
            SampleComparison(
                sample_number=sample_number,
                timestamp=timestamp,
                vmaf_mean=mean_score,
                vmaf_p05=p05_score,
                combined_score=(mean_score + p05_score) / 2,
                bitrate_bps=bitrate(output),
            )
        )

        print(
            f"Sample {sample_number}/{SAMPLE_COUNT}: mean={mean_score:.3f}, "
            f"p05={p05_score:.3f}, combined={(mean_score + p05_score) / 2:.3f}"
        )
    return comparisons
