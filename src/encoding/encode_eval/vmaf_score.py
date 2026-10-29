import json
import subprocess
import tempfile
from pathlib import Path

from .percentile import percentile
from .settings import VMAF_DEFAULT_MODEL, VMAF_NEG_MODEL


def vmaf_score(
    reference: Path, distorted: Path, use_neg_model: bool = False
) -> tuple[float, float]:
    model = VMAF_NEG_MODEL if use_neg_model else VMAF_DEFAULT_MODEL

    with tempfile.TemporaryDirectory(prefix="encoding-vmaf-") as log_directory:
        log_path = Path(log_directory) / "vmaf.json"
        filter_graph = (
            "[0:v]setpts=PTS-STARTPTS[distorted];"
            "[1:v]setpts=PTS-STARTPTS[reference];"
            f"[distorted][reference]libvmaf=model=version={model}:"
            "log_fmt=json:log_path=vmaf.json:shortest=1"
        )

        try:
            subprocess.run(
                [
                    "ffmpeg.exe",
                    "-hide_banner",
                    "-nostats",
                    "-i",
                    str(distorted.resolve()),
                    "-i",
                    str(reference.resolve()),
                    "-filter_complex",
                    filter_graph,
                    "-f",
                    "null",
                    "-",
                ],
                capture_output=True,
                text=True,
                check=True,
                cwd=log_directory,
            )
        except subprocess.CalledProcessError as error:
            details = (error.stderr or error.stdout or "").strip()
            raise RuntimeError(f"VMAF comparison failed: {details}") from error

        if not log_path.is_file():
            raise RuntimeError(
                "FFmpeg completed the VMAF comparison without creating its JSON log."
            )

        try:
            result = json.loads(log_path.read_text(encoding="utf-8"))
            frame_scores = [
                float(frame["metrics"]["vmaf"])
                for frame in result["frames"]
                if "vmaf" in frame["metrics"]
            ]
            mean_score = float(result["pooled_metrics"]["vmaf"]["mean"])
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
            raise RuntimeError(
                f"Could not parse per-frame VMAF results: {error}"
            ) from error

        if not frame_scores:
            raise RuntimeError("VMAF JSON log contains no per-frame VMAF scores.")

        return mean_score, percentile(frame_scores, 5)
