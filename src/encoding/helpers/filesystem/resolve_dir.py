from pathlib import Path


def resolve_dir(
    directory: str | Path | None, throw_on_not_found: bool = True
) -> Path | None:
    value = str(directory or ".").strip().strip('"').strip("'")
    path = Path(value).expanduser()

    if not path.is_dir():
        if throw_on_not_found:
            raise FileNotFoundError(f"Directory not found: {value}")

        return None

    return path.resolve()
