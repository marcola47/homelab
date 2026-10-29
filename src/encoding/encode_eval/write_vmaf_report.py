from pathlib import Path

from encoding.types.sample_comparison import SampleComparison


def write_vmaf_report(
    report_path: Path,
    source: Path,
    preset_label: str,
    quality: int,
    comparisons: list[SampleComparison],
    model: str,
) -> None:
    if not comparisons:
        raise ValueError("Cannot write a VMAF report without sample comparisons.")

    mean_vmaf = sum(item.vmaf_mean for item in comparisons) / len(comparisons)
    mean_p05 = sum(item.vmaf_p05 for item in comparisons) / len(comparisons)
    mean_combined = sum(item.combined_score for item in comparisons) / len(comparisons)
    mean_bitrate = sum(item.bitrate_bps for item in comparisons) / len(comparisons)

    lines = [
        f"# VMAF Evaluation: {source.name}",
        "",
        f"- Preset: {preset_label}",
        f"- Quality target (CQ): {quality}",
        f"- VMAF model: `{model}`",
        "",
        "| Sample | Timestamp | Mean VMAF | 5th percentile | Combined score | Bitrate (kbps) |",
        "|---:|:---:|---:|---:|---:|---:|",
    ]

    for item in comparisons:
        lines.append(
            f"| {item.sample_number} | {item.timestamp} | {item.vmaf_mean:.3f} "
            f"| {item.vmaf_p05:.3f} | {item.combined_score:.3f} "
            f"| {item.bitrate_bps / 1000:.1f} |"
        )

    lines.extend(
        [
            "",
            f"- **Average mean VMAF:** {mean_vmaf:.3f}",
            f"- **Average 5th-percentile VMAF:** {mean_p05:.3f}",
            f"- **Average combined score:** {mean_combined:.3f}",
            f"- **Average bitrate:** {mean_bitrate / 1000:.1f} kbps",
            "",
        ]
    )

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")
