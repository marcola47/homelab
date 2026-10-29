from encoding.types.gpu_preset import GpuPreset


def nvenc_video_args(cq: int, preset: GpuPreset) -> list[str]:
    return [
        "-c:v",
        "av1_nvenc",
        "-split_encode_mode",
        "auto",
        "-preset",
        "p7",
        "-tune",
        "uhq",
        "-rc",
        "vbr",
        "-cq",
        str(cq),
        "-b:v",
        "0",
        "-g",
        "240",
        "-rc-lookahead",
        "48",
        "-multipass",
        "fullres",
        "-spatial-aq",
        str(int(preset.spatial_aq)),
        "-temporal-aq",
        str(int(preset.temporal_aq)),
        "-aq-strength",
        str(preset.aq_strength),
    ]
