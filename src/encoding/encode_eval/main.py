import argparse

from encoding.helpers.filesystem import get_video_files, resolve_dir

from .evaluate_source import evaluate_source


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate AV1 quality targets against source samples with VMAF."
    )
    parser.add_argument("directory", nargs="?")
    args = parser.parse_args()
    directory = args.directory or input(
        "Enter directory path (or press Enter for current directory): "
    )

    try:
        root = resolve_dir(directory)
        assert root is not None

        sources = get_video_files(
            root,
            (".mkv", ".mp4", ".avi"),
            exclude_patterns=(r"[\\/]+samples[\\/]", r"[\\/]+encoded[\\/]"),
        )

        if not sources:
            raise FileNotFoundError(f"No supported video files found under '{root}'.")

        for source in sources:
            print(f"\nSource: {source}")
            evaluate_source(source)

        print("\nAll evaluations completed successfully.")
    except Exception as error:
        print(f"\nFATAL ERROR: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
