from dataclasses import dataclass


@dataclass(frozen=True)
class SampleComparison:
    sample_number: int
    timestamp: str
    vmaf_mean: float
    vmaf_p05: float
    combined_score: float
    bitrate_bps: int
    neg_mean: float | None = None
    neg_p05: float | None = None
