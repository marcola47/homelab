from dataclasses import dataclass


@dataclass(frozen=True)
class GpuPreset:
    label: str
    spatial_aq: bool
    temporal_aq: bool
    aq_strength: int


GPU_PRESETS = {
    "1": GpuPreset("Animation", True, False, 2),
    "2": GpuPreset("Film", True, False, 1),
    "3": GpuPreset("Digital", True, True, 3),
    "4": GpuPreset("Phone/camera recordings", True, True, 2),
}
