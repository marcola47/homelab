from .seconds_to_timestamp import seconds_to_timestamp
from .settings import SAMPLE_COUNT, SAMPLE_DURATION_SECONDS


def sample_timestamps(duration: float) -> list[str]:
    latest_start = duration - SAMPLE_DURATION_SECONDS

    if latest_start <= 0:
        raise ValueError(
            f"Video duration must be longer than {SAMPLE_DURATION_SECONDS} seconds "
            "to sample across its timeline."
        )

    return [
        seconds_to_timestamp(latest_start * index / (SAMPLE_COUNT - 1))
        for index in range(SAMPLE_COUNT)
    ]
