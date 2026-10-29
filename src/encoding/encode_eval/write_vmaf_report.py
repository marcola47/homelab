from pathlib import Path

from encoding.helpers.encoding import ENCODING_PROFILE
from encoding.types.sample_comparison import SampleComparison

from .settings import VMAF_MODEL, VMAF_NEG_MODEL


def write_vmaf_report(
    report_path: Path,
    source: Path,
    quality: int,
    comparisons: list[SampleComparison],
) -> None:
    if not comparisons:
        raise ValueError("Cannot write a VMAF report without sample comparisons.")

    mean_vmaf = sum(item.vmaf_mean for item in comparisons) / len(comparisons)
    mean_neg_vmaf = sum(item.vmaf_neg_mean for item in comparisons) / len(comparisons)
    mean_combined = sum(item.combined_score for item in comparisons) / len(comparisons)
    mean_bitrate = sum(item.bitrate_bps for item in comparisons) / len(comparisons)

    lines = [
        f"# VMAF Evaluation: {source.name}",
        "",
        f"- Encoding profile: {ENCODING_PROFILE}",
        f"- Quality target (CQ): {quality}",
        f"- VMAF models: `{VMAF_MODEL}` and `{VMAF_NEG_MODEL}`",
        "- Final score = (VMAF mean + 2 × NEG mean) / 3.",
        "",
        "| Sample | Timestamp | VMAF mean | NEG mean | Final score | Bitrate (kbps) |",
        "|---:|:---:|---:|---:|---:|---:|",
    ]

    for item in comparisons:
        lines.append(
            f"| {item.sample_number} | {item.timestamp} | {item.vmaf_mean:.3f} "
            f"| {item.vmaf_neg_mean:.3f} | {item.combined_score:.3f} "
            f"| {item.bitrate_bps / 1000:.1f} |"
        )

    lines.extend(
        [
            "",
            f"- **Average mean VMAF:** {mean_vmaf:.3f}",
            f"- **Average NEG mean:** {mean_neg_vmaf:.3f}",
            f"- **Average final score:** {mean_combined:.3f}",
            f"- **Average bitrate:** {mean_bitrate / 1000:.1f} kbps",
            "",
        ]
    )

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")
