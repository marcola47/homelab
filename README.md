# Encoding scripts

The encoding tools use FFmpeg and ffprobe.

- `uv run encode` transcodes videos using the AV1 NVENC preset.
- `uv run encode_eval` creates 10-second samples and compares them with VMAF.
  Choose option 0 to compare Digital, Animation, and Film presets and generate
  an aggregate report in each video's `samples` folder.
