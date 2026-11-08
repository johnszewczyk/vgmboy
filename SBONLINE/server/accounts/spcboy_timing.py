from pathlib import PurePosixPath


DEFAULT_SPC_TOTAL_MS = 180_000
DEFAULT_SPC_FADE_MS = 5_000
LONG_PLAY_SECONDS = 86_400


def catalog_duration_seconds(track, metadata):
    member_name = str(metadata.get("member") or "")
    if PurePosixPath(member_name).suffix.casefold() == ".spc":
        return DEFAULT_SPC_TOTAL_MS // 1000
    return track.get("durationSeconds", 0)


def long_play_timing(seconds, fade_ms, start_ms, session_remaining_ms, speed_numerator=2, speed_denominator=1):
    """Zero is uncapped music timing; the hosted session still bounds decoding."""
    if not isinstance(seconds, int) or isinstance(seconds, bool) or not 0 <= seconds <= LONG_PLAY_SECONDS:
        raise ValueError("Long Play must be 0 to 86400 whole seconds.")
    if seconds == 0:
        if not 0 <= start_ms < LONG_PLAY_SECONDS * 1000:
            raise ValueError("Invalid playback position.")
        # Convert the remaining wall-clock session into source time at the
        # selected decoder tempo; HTTP still enforces the independent deadline.
        remaining_source_ms = (max(1, session_remaining_ms) * speed_numerator + speed_denominator - 1) // speed_denominator
        end_ms = min(LONG_PLAY_SECONDS * 1000, start_ms + remaining_source_ms)
        return end_ms, 0
    total_ms = seconds * 1000
    fade_ms = max(0, min(fade_ms, total_ms - 1))
    return total_ms - fade_ms, fade_ms
