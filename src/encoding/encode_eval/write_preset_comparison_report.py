from pathlib import Path

from encoding.types.sample_comparison import SampleComparison


def write_preset_comparison_report(
    report_path: Path,
    source: Path,
    comparisons: dict[str, dict[int, list[SampleComparison]]],
    neg_comparisons: dict[int, list[SampleComparison]],
) -> None:
    lines = [
        f"# Preset Comparison: {source.name}",
        "",
        "The same five source timestamps were used for each preset and quality target.",
        "Scores use the standard VMAF model for cross-preset comparison.",
        "",
    ]

    for preset_label, qualities in comparisons.items():
        lines.extend([f"## {preset_label}", ""])
        lines.extend(
            [
                "| CQ | Sample | Timestamp | Mean VMAF | 5th percentile | Combined score | Bitrate (kbps) |",
                "|---:|---:|:---:|---:|---:|---:|---:|",
            ]
        )

        for quality, samples in qualities.items():
            for item in samples:
                lines.append(
                    f"| {quality} | {item.sample_number} | {item.timestamp} "
                    f"| {item.vmaf_mean:.3f} | {item.vmaf_p05:.3f} "
                    f"| {item.combined_score:.3f} | {item.bitrate_bps / 1000:.1f} |"
                )

            if samples:
                avg_mean = sum(sample.vmaf_mean for sample in samples) / len(samples)
                avg_p05 = sum(sample.vmaf_p05 for sample in samples) / len(samples)
                avg_combined = sum(sample.combined_score for sample in samples) / len(
                    samples
                )
                avg_bitrate = (
                    sum(sample.bitrate_bps for sample in samples) / len(samples) / 1000
                )
                lines.append(
                    f"| **{quality} average** |  |  | **{avg_mean:.3f}** "
                    f"| **{avg_p05:.3f}** | **{avg_combined:.3f}** "
                    f"| **{avg_bitrate:.1f}** |"
                )
        lines.append("")

    if neg_comparisons:
        lines.extend(
            [
                "## Film preset NEG scores",
                "",
                "| CQ | Sample | Timestamp | Mean NEG VMAF | 5th percentile NEG | Combined NEG score |",
                "|---:|---:|:---:|---:|---:|---:|",
            ]
        )

        for quality, samples in neg_comparisons.items():
            for item in samples:
                mean = item.neg_mean if item.neg_mean is not None else item.vmaf_mean
                p05 = item.neg_p05 if item.neg_p05 is not None else item.vmaf_p05
                lines.append(
                    f"| {quality} | {item.sample_number} | {item.timestamp} "
                    f"| {mean:.3f} | {p05:.3f} "
                    f"| {(mean + p05) / 2:.3f} |"
                )

            if samples:
                means = [
                    item.neg_mean if item.neg_mean is not None else item.vmaf_mean
                    for item in samples
                ]
                p05s = [
                    item.neg_p05 if item.neg_p05 is not None else item.vmaf_p05
                    for item in samples
                ]
                avg_mean = sum(means) / len(means)
                avg_p05 = sum(p05s) / len(p05s)
                lines.append(
                    f"| **{quality} average** |  |  | **{avg_mean:.3f}** "
                    f"| **{avg_p05:.3f}** | **{(avg_mean + avg_p05) / 2:.3f}** |"
                )
        lines.append("")

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")
