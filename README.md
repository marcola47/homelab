# Encoding scripts

The encoding tools use FFmpeg and ffprobe.

- `uv run encode` transcodes videos using the AV1 NVENC preset.
- `uv run encode_eval` creates 10-second samples and compares them with VMAF.
  Both tools use the same AV1 NVENC `p7` / `uhq` encoding profile. Evaluations
  report five samples and their average for each configured CQ target.
