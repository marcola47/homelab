from pathlib import Path

from .get_subtitle_streams import get_subtitle_streams

COPY_SUBTITLES = {
    "ass",
    "ssa",
    "subrip",
    "srt",
    "webvtt",
    "hdmv_pgs_subtitle",
    "dvd_subtitle",
    "pgssub",
}
CONVERT_SUBTITLES = {"mov_text", "tx3g"}


def subtitle_args(file: Path) -> list[str]:
    args: list[str] = []
    output_index = 0

    for stream in get_subtitle_streams(file):
        codec, index = stream.get("codec_name", "").lower(), stream.get("index")

        if codec in COPY_SUBTITLES:
            args += ["-map", f"0:{index}", f"-c:s:{output_index}", "copy"]
            output_index += 1
            print(f"  Subtitle stream {index} ({codec}): copying")
        elif codec in CONVERT_SUBTITLES:
            args += ["-map", f"0:{index}", f"-c:s:{output_index}", "srt"]
            output_index += 1
            print(f"  Subtitle stream {index} ({codec}): converting to SRT")
        else:
            print(
                f"  Subtitle stream {index} ({codec}): dropping (unsupported/unconvertible)"
            )

    return args
