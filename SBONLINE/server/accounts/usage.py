import time
from datetime import timezone as datetime_timezone

from asgiref.sync import sync_to_async
from django.core import signing
from django.db.models import F
from django.utils import timezone

from .models import (
    MonthlyUsage,
    PLAYER_SESSION_LIMIT_MINUTES_MAX,
    PLAYER_SESSION_LIMIT_MINUTES_MIN,
    SiteSettings,
)


MEDIA_PREFIXES = ("/audio/", "/media/")
MONTHLY_AUDIO_STREAM_LIMIT_BYTES = 10_000_000_000
PLAYER_PAGE_LOAD_TOKEN_SALT = "accounts.spcboy-playback-page-load"
DEFAULT_PLAYER_SESSION_LIMIT_MINUTES = 120
LEGACY_PLAYER_SESSION_MAX_AGE_SECONDS = 60 * 60
PLAYER_SESSION_MAX_AGE_SECONDS = PLAYER_SESSION_LIMIT_MINUTES_MAX * 60


def player_session_limit_seconds():
    configured_minutes = SiteSettings.objects.filter(pk=1).values_list(
        "player_session_limit_minutes", flat=True
    ).first()
    if (
        type(configured_minutes) is not int
        or not PLAYER_SESSION_LIMIT_MINUTES_MIN <= configured_minutes <= PLAYER_SESSION_LIMIT_MINUTES_MAX
    ):
        configured_minutes = DEFAULT_PLAYER_SESSION_LIMIT_MINUTES
    return configured_minutes * 60


def player_page_load_salt(user_id):
    return f"{PLAYER_PAGE_LOAD_TOKEN_SALT}:{user_id}"


def _month_start():
    return timezone.now().astimezone(datetime_timezone.utc).date().replace(day=1)


def _record_usage(user_id, bucket, byte_count, period):
    if byte_count <= 0:
        return
    usage, _ = MonthlyUsage.objects.get_or_create(
        user_id=user_id,
        period=period,
    )
    MonthlyUsage.objects.filter(pk=usage.pk).update(
        **{bucket: F(bucket) + byte_count},
        updated_at=timezone.now(),
    )


def audio_stream_usage(user_id, period=None):
    period = period or _month_start()
    return MonthlyUsage.objects.filter(user_id=user_id, period=period).values_list(
        "audio_bytes", flat=True
    ).first() or 0


def audio_stream_remaining(user_id, period=None):
    return max(0, MONTHLY_AUDIO_STREAM_LIMIT_BYTES - audio_stream_usage(user_id, period))


def claim_audio_stream_bytes(user_id, byte_count, period=None):
    """Atomically claim only encoded audio bytes that fit under this account's monthly cap."""
    if byte_count <= 0:
        return 0
    period = period or _month_start()
    usage, _ = MonthlyUsage.objects.get_or_create(user_id=user_id, period=period)
    # The common path is one atomic UPDATE, not a read/compare/write race.
    # Concurrent tabs must not exhaust retries and look like an empty quota.
    if MonthlyUsage.objects.filter(
        pk=usage.pk, audio_bytes__lte=MONTHLY_AUDIO_STREAM_LIMIT_BYTES-byte_count,
    ).update(audio_bytes=F("audio_bytes")+byte_count, updated_at=timezone.now()):
        return byte_count
    for _ in range(8):
        current = MonthlyUsage.objects.filter(pk=usage.pk).values_list("audio_bytes", flat=True).first()
        remaining = max(0, MONTHLY_AUDIO_STREAM_LIMIT_BYTES - (current or 0))
        amount = min(byte_count, remaining)
        if amount <= 0:
            return 0
        claimed = MonthlyUsage.objects.filter(pk=usage.pk, audio_bytes=current).update(
            audio_bytes=F("audio_bytes") + amount,
            updated_at=timezone.now(),
        )
        if claimed:
            return amount
    return 0


def _byte_count(chunk):
    if isinstance(chunk, str):
        return len(chunk.encode("utf-8"))
    return len(chunk)


class PrivateUsageMiddleware:
    """Aggregate authenticated response-body bytes for this private app."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, "user", None)
        request.spcboy_page_load_token = ""
        request.spcboy_session_limit_seconds = 0
        if user and user.is_authenticated:
            supplied_token = request.headers.get("X-Playback-Page-Token", "")
            if request.headers.get("X-Site-Navigation") == "1":
                request.spcboy_page_load_token = supplied_token
            elif request.method == "GET" and "text/html" in request.headers.get("Accept", ""):
                loaded_at = int(time.time())
                session_limit_seconds = player_session_limit_seconds()
                request.spcboy_session_limit_seconds = session_limit_seconds
                request.spcboy_page_load_token = signing.dumps(
                    {
                        "loaded_at": loaded_at,
                        "session_limit_seconds": session_limit_seconds,
                    },
                    salt=player_page_load_salt(user.pk),
                )

        response = self.get_response(request)
        if (
            not user
            or not user.is_authenticated
            or request.method == "HEAD"
            or response.status_code >= 400
            or response.status_code in {204, 304}
        ):
            return response

        bucket = "media_bytes" if request.path.startswith(MEDIA_PREFIXES) else "site_bytes"
        period = _month_start()
        if response.streaming:
            if response.is_async:
                response.streaming_content = self._count_async(
                    response.streaming_content, user.pk, bucket, period
                )
            else:
                response.streaming_content = self._count_sync(
                    response.streaming_content, user.pk, bucket, period
                )
            return response

        _record_usage(user.pk, bucket, len(response.content), period)
        return response

    @staticmethod
    def _count_sync(content, user_id, bucket, period):
        count = 0
        try:
            for chunk in content:
                count += _byte_count(chunk)
                yield chunk
        finally:
            _record_usage(user_id, bucket, count, period)

    @staticmethod
    async def _count_async(content, user_id, bucket, period):
        count = 0
        try:
            async for chunk in content:
                count += _byte_count(chunk)
                yield chunk
        finally:
            await sync_to_async(_record_usage, thread_sensitive=True)(user_id, bucket, count, period)
