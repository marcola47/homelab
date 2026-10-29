from pathlib import Path

from encoding.helpers.media import ffprobe_output


def get_subtitle_streams(file_path: str | Path) -> list[dict[str, str]]:
    try:
        output = ffprobe_output(
            [
                "-v",
                "error",
                "-select_streams",
                "s",
                "-show_entries",
                "stream=index,codec_name",
                "-of",
                "csv=p=0",
            ],
            file_path,
        )
    except OSError, RuntimeError:
        return []

    fields = ("index", "codec_name")
    streams = []

    for line in output.splitlines():
        values = line.split(",")

        if len(values) >= len(fields):
            streams.append(dict(zip(fields, values, strict=False)))

    return streams
