from pathlib import Path

from encoding.helpers.media import ffprobe_output


def get_audio_args(file_path: str | Path) -> list[str]:
    try:
        value = ffprobe_output(
            [
                "-v",
                "error",
                "-select_streams",
                "a:0",
                "-show_entries",
                "stream=channels",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
            ],
            file_path,
        )
        channels = int(value.splitlines()[0]) if value else 2
    except OSError, ValueError, RuntimeError:
        channels = 2

    if channels > 2:
        audio_filter = (
            "aresample=48000:resampler=soxr,"
            "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL+0.5*LFE|"
            "FR=FR+0.707*FC+0.5*BR+0.5*SR+0.5*LFE,"
            "loudnorm=I=-18:TP=-1.5:LRA=11"
        )
    else:
        audio_filter = "aresample=48000:resampler=soxr,loudnorm=I=-16:TP=-1.5:LRA=11"

    return [
        "-af",
        audio_filter,
        "-ac",
        "2",
        "-c:a",
        "libopus",
        "-b:a",
        "128k",
        "-vbr",
        "on",
        "-apply_phase_inv",
        "0",
        "-compression_level",
        "10",
        "-application",
        "lowdelay",
        "-frame_duration",
        "40",
    ]
