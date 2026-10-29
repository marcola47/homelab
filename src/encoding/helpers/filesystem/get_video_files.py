import re
from collections.abc import Iterable
from pathlib import Path

from .resolve_dir import resolve_dir


def get_video_files(
    directory: str | Path,
    extensions: Iterable[str] = (".mkv", ".mp4"),
    recursive: bool = True,
    exclude_patterns: Iterable[str] = (),
    sort: bool = True,
) -> list[Path]:
    root = resolve_dir(directory)
    assert root is not None

    allowed = {ext.lower() for ext in extensions}
    iterator = root.rglob("*") if recursive else root.iterdir()
    patterns = tuple(re.compile(pattern, re.IGNORECASE) for pattern in exclude_patterns)
    files = [
        path
        for path in iterator
        if path.is_file()
        and path.suffix.lower() in allowed
        and not any(pattern.search(str(path)) for pattern in patterns)
    ]

    return sorted(files, key=lambda path: str(path).casefold()) if sort else files
