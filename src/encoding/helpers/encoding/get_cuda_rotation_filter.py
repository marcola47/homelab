import json
import math
from pathlib import Path

from encoding.helpers.media import ffprobe_output


def get_cuda_rotation_filter(file_path: str | Path) -> str | None:
    output = ffprobe_output(
        [
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream_side_data=rotation",
            "-of",
            "json",
        ],
        file_path,
    )

    try:
        stream = json.loads(output)["streams"][0]
    except (IndexError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise RuntimeError(
            f"Could not read video rotation metadata for '{file_path}': {error}"
        ) from error

    if not isinstance(stream, dict):
        raise RuntimeError(f"Invalid ffprobe video stream data for '{file_path}'.")

    side_data = stream.get("side_data_list", [])
    if not isinstance(side_data, list):
        raise RuntimeError(f"Invalid ffprobe rotation data for '{file_path}'.")

    rotations = [
        item["rotation"]
        for item in side_data
        if isinstance(item, dict) and "rotation" in item
    ]
    if not rotations:
        return None

    try:
        angles = [
            float(rotation) for rotation in rotations if not isinstance(rotation, bool)
        ]
    except (TypeError, ValueError) as error:
        raise RuntimeError(
            f"Invalid rotation value reported for '{file_path}'."
        ) from error

    if len(angles) != len(rotations) or not all(map(math.isfinite, angles)):
        raise RuntimeError(f"Invalid rotation value reported for '{file_path}'.")

    quarter_turns: set[int] = set()
    for angle in angles:
        normalized = angle % 360
        turns = round(normalized / 90) % 4
        nearest_angle = turns * 90
        difference = abs(normalized - nearest_angle)
        if min(difference, 360 - difference) > 0.1:
            raise RuntimeError(
                f"Unsupported rotation angle {angle} for '{file_path}'; "
                "CUDA transpose supports multiples of 90 degrees."
            )
        quarter_turns.add(turns)

    if len(quarter_turns) != 1:
        raise RuntimeError(f"Conflicting rotation values reported for '{file_path}'.")

    return {
        0: None,
        1: "transpose_cuda=cclock",
        2: "transpose_cuda=reversal",
        3: "transpose_cuda=clock",
    }[quarter_turns.pop()]
