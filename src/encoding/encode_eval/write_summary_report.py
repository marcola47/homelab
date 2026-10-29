from pathlib import Path

from encoding.helpers.encoding import ENCODING_PROFILE
from encoding.types.sample_comparison import SampleComparison

from .settings import VMAF_MODEL, VMAF_NEG_MODEL


def write_summary_report(
    report_path: Path,
    source: Path,
    comparisons_by_quality: dict[int, list[SampleComparison]],
) -> None:
    if not comparisons_by_quality:
        raise ValueError("Cannot write a summary without quality comparisons.")

    if any(not comparisons for comparisons in comparisons_by_quality.values()):
        raise ValueError("Cannot summarize an empty quality comparison.")

    lines = [
        f"# VMAF Summary: {source.name}",
        "",
        f"- Encoding profile: {ENCODING_PROFILE}",
        f"- VMAF models: `{VMAF_MODEL}` and `{VMAF_NEG_MODEL}`",
        "- Final score = (VMAF mean + 2 × NEG mean) / 3.",
        "",
        "| CQ | VMAF mean | NEG mean | Final score | Bitrate (kbps) |",
        "|---:|---:|---:|---:|---:|",
    ]

    for quality, comparisons in comparisons_by_quality.items():
        count = len(comparisons)
        avg_vmaf = sum(item.vmaf_mean for item in comparisons) / count
        avg_neg = sum(item.vmaf_neg_mean for item in comparisons) / count
        avg_final = sum(item.combined_score for item in comparisons) / count
        avg_bitrate = sum(item.bitrate_bps for item in comparisons) / count / 1000
        lines.append(
            f"| {quality} | {avg_vmaf:.3f} | {avg_neg:.3f} "
            f"| {avg_final:.3f} | {avg_bitrate:.1f} |"
        )

    lines.append("")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")
