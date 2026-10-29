from dataclasses import dataclass


@dataclass(frozen=True)
class SampleComparison:
    sample_number: int
    timestamp: str
    vmaf_mean: float
    vmaf_neg_mean: float
    combined_score: float
    bitrate_bps: int
