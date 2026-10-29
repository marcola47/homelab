from pathlib import Path

from encoding.types.sample_comparison import SampleComparison

from .bitrate import bitrate
from .encode_sample import encode_sample
from .settings import SAMPLE_COUNT, VMAF_MODEL, VMAF_NEG_MODEL
from .vmaf_score import vmaf_score


def compare_samples(
    source: Path,
    references: list[tuple[str, Path]],
    quality: int,
    output_directory: Path,
) -> list[SampleComparison]:
    comparisons: list[SampleComparison] = []
    for sample_number, (timestamp, reference) in enumerate(references, start=1):
        output = output_directory / f"sample_{sample_number:02d}.mkv"
        encode_sample(source, output, timestamp, quality)

        mean_score = vmaf_score(reference, output, VMAF_MODEL)
        neg_mean_score = vmaf_score(reference, output, VMAF_NEG_MODEL)
        combined_score = (mean_score + 2 * neg_mean_score) / 3
        comparisons.append(
            SampleComparison(
                sample_number=sample_number,
                timestamp=timestamp,
                vmaf_mean=mean_score,
                vmaf_neg_mean=neg_mean_score,
                combined_score=combined_score,
                bitrate_bps=bitrate(output),
            )
        )

        print(
            f"Sample {sample_number}/{SAMPLE_COUNT}: VMAF mean={mean_score:.3f}, "
            f"NEG mean={neg_mean_score:.3f}; combined={combined_score:.3f}"
        )
    return comparisons
