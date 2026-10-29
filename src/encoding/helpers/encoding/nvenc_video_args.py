ENCODING_PROFILE = "AV1 NVENC p7 UHQ"


def nvenc_video_args(cq: int) -> list[str]:
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
        "1",
        "-temporal-aq",
        "1",
        "-aq-strength",
        "3",
    ]
