import base64
import hashlib
import hmac
import io
import json
import logging
import mimetypes
import secrets
import select
import shutil
import sqlite3
import subprocess
import tempfile
import time
import uuid
import warnings
from datetime import datetime, time as datetime_time, timedelta, timezone as datetime_timezone
from pathlib import Path, PurePosixPath

from PIL import Image, ImageOps, UnidentifiedImageError
from pillow_heif import register_heif_opener
from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings
from django.contrib import messages
from django.contrib.auth import get_user_model, login, logout as auth_logout
from django.contrib.auth.decorators import login_required
from django.core import signing
from django.contrib.sessions.models import Session
from django.core.exceptions import PermissionDenied
from django.core.files.base import ContentFile
from django.core.paginator import Paginator
from django.core.files.storage import default_storage
from django.db import DatabaseError, IntegrityError, transaction
from django.db.models import Count, F, Max, Q, Value
from django.db.models.functions import Greatest, TruncDate
from django.http import FileResponse, Http404, HttpResponse, HttpResponseBadRequest, HttpResponseGone, JsonResponse, StreamingHttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_GET, require_http_methods, require_POST, require_safe
from django.views.generic import TemplateView

from .aac_transport import AACADTSPrimingFrameStripper
from .forms import MAX_PROFILE_IMAGE_BYTES, EnrollmentForm, MemberProfileForm, SiteSettingsForm
from .catalog_search import adjacent_catalog_track, build_catalog_index, catalog_index_is_current, query_catalog_index, search_terms
from .spcboy_timing import (
    DEFAULT_SPC_FADE_MS,
    DEFAULT_SPC_TOTAL_MS,
    long_play_timing,
    catalog_duration_seconds,
)
from .login_audit import (
    active_login_sessions,
    close_missing_sessions,
    mark_session_signed_out,
    online_user_count,
    request_ip_address,
    request_user_agent,
    session_key_digest,
)
from .models import (
    AccessKeyCredential,
    FavoriteAlbum,
    FavoriteTrack,
    Invitation,
    InviteCodeAttempt,
    LoginEvent,
    MemberActivityReadState,
    MemberProfile,
    SiteSettings,
    MonthlyUsage,
    PasskeyAccount,
    PasskeyCredential,
    SPCBOYNowPlaying,
    SPCBOYPlaybackHistory,
    SPCBOYRecentHidden,
)

register_heif_opener()
from .spcboy_gallery import (
    THUMBNAIL_EXTENSION,
    THUMBNAIL_MIME_TYPE,
    spcboy_album_id,
)
from .spcboy_catalog import (
    attach_track_artwork as _attach_track_artwork,
    catalog_album_index as _catalog_album_index,
    catalog_track_index as _catalog_track_index,
    favorite_album_rows as _favorite_album_rows,
    public_spcboy_track as _public_spcboy_track,
    spcboy_artwork_url as _spcboy_artwork_url,
    spcboy_catalog_data as _spcboy_catalog_data,
    spcboy_gallery_index as _spcboy_gallery_index,
    track_artwork_url as _track_artwork_url,
)
from .vgmboy_prepare import prepare_selected_member as prepare_with_vgmboy
from .passkeys import (
    authentication_options,
    registration_options,
    verify_authentication,
    verify_registration,
)
from .usage import (
    MONTHLY_AUDIO_STREAM_LIMIT_BYTES,
    LEGACY_PLAYER_SESSION_MAX_AGE_SECONDS,
    PLAYER_SESSION_MAX_AGE_SECONDS,
    PLAYER_SESSION_LIMIT_MINUTES_MAX,
    PLAYER_SESSION_LIMIT_MINUTES_MIN,
    _month_start,
    audio_stream_remaining,
    audio_stream_usage,
    claim_audio_stream_bytes,
    player_page_load_salt,
)


User = get_user_model()
logger = logging.getLogger(__name__)
INVITE_LIFETIME = timedelta(hours=24)
PENDING_ENROLLMENT_LIFETIME = timedelta(hours=1)
MAX_PASSKEY_ATTEMPTS = 5
MAX_INVITE_FAILURES = 5
INVITE_FAILURE_WINDOW = timedelta(minutes=15)
INVITE_BLOCK_DURATION = timedelta(hours=24)
MAX_PROFILE_IMAGE_PIXELS = 60_000_000
NOW_PLAYING_TTL = timedelta(seconds=75)
MONITORED_INTERFACE = "eth0"
VNSTAT_PATH = "/usr/bin/vnstat"


def _owner_required(request):
    if not request.user.is_authenticated:
        return redirect("login")
    if not request.user.is_superuser:
        raise PermissionDenied
    return None


@method_decorator(never_cache, name="dispatch")
class PrivateLoginView(TemplateView):
    template_name = "accounts/login.html"

    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return redirect("spcboy")
        return super().dispatch(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["next"] = kwargs.get("next", self.request.GET.get("next", ""))
        context["access_key_error"] = kwargs.get("access_key_error", "")
        return context

    def post(self, request, *args, **kwargs):
        next_url = request.POST.get("next", "")
        blocked_until = _invite_blocked_until(request)
        if blocked_until:
            response = self.render_to_response(
                self.get_context_data(
                    next=next_url,
                    access_key_error="Sign-in from this connection is paused for 24 hours after too many failed attempts.",
                ),
                status=429,
            )
            response["Retry-After"] = str(max(1, int((blocked_until - timezone.now()).total_seconds())))
            return response

        key = request.POST.get("access_key", "").strip()
        valid_shape = len(key) == 43 and all(
            character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
            for character in key
        )
        credential = None
        if valid_shape:
            with transaction.atomic():
                credential = AccessKeyCredential.objects.select_for_update().select_related("user").filter(
                    key_digest=_access_key_digest(key),
                    user__is_active=True,
                ).first()
                if credential is not None:
                    credential.last_used_at = timezone.now()
                    credential.save(update_fields=["last_used_at"])

        if credential is None:
            _passkey_failure(request)
            blocked_until = _record_invite_failure(request)
            error = (
                "Sign-in from this connection is paused for 24 hours after too many failed attempts."
                if blocked_until and blocked_until > timezone.now()
                else "That login password was not accepted."
            )
            response = self.render_to_response(
                self.get_context_data(next=next_url, access_key_error=error),
                status=429 if blocked_until and blocked_until > timezone.now() else 400,
            )
            if blocked_until and blocked_until > timezone.now():
                response["Retry-After"] = str(max(1, int((blocked_until - timezone.now()).total_seconds())))
            return response

        InviteCodeAttempt.objects.filter(ip_digest=_invite_attempt_digest(request)).delete()
        login(request, credential.user, backend=settings.AUTHENTICATION_BACKENDS[0])
        if not url_has_allowed_host_and_scheme(
            next_url,
            allowed_hosts={request.get_host()},
            require_https=request.is_secure(),
        ):
            next_url = reverse("spcboy")
        return redirect(next_url)

def _digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _invitation_cipher(secret_key):
    key_material = hashlib.sha256(
        b"precalc-admin:invitation-code:v1\0" + secret_key.encode("utf-8")
    ).digest()
    return Fernet(base64.urlsafe_b64encode(key_material))


def _encrypt_invitation_code(code):
    return _invitation_cipher(settings.SECRET_KEY).encrypt(code.encode("ascii")).decode("ascii")


def _decrypt_invitation_code(invitation):
    if not invitation.invitation_code_ciphertext:
        return None
    secrets_to_try = [settings.SECRET_KEY, *getattr(settings, "SECRET_KEY_FALLBACKS", [])]
    for secret_key in secrets_to_try:
        try:
            return _invitation_cipher(secret_key).decrypt(
                invitation.invitation_code_ciphertext.encode("ascii")
            ).decode("ascii")
        except (InvalidToken, UnicodeDecodeError, UnicodeEncodeError, ValueError):
            continue
    return None


def _access_key_digest(value):
    secret = settings.SECRET_KEY.encode("utf-8")
    payload = b"precalc-private-access-key\0" + value.encode("ascii")
    return hmac.new(secret, payload, hashlib.sha256).hexdigest()


def _invite_attempt_digest(request):
    address = request_ip_address(request) or request.META.get("REMOTE_ADDR") or "unknown"
    secret = settings.SECRET_KEY.encode("utf-8")
    return hmac.new(secret, str(address).encode("utf-8"), hashlib.sha256).hexdigest()


def _invite_blocked_until(request):
    attempt = InviteCodeAttempt.objects.filter(ip_digest=_invite_attempt_digest(request)).first()
    now = timezone.now()
    return attempt.blocked_until if attempt and attempt.blocked_until and attempt.blocked_until > now else None


def _record_invite_failure(request):
    now = timezone.now()
    key = _invite_attempt_digest(request)
    with transaction.atomic():
        attempt, _ = InviteCodeAttempt.objects.select_for_update().get_or_create(ip_digest=key)
        if attempt.blocked_until and attempt.blocked_until > now:
            return attempt.blocked_until
        if attempt.window_started_at < now - INVITE_FAILURE_WINDOW:
            attempt.failed_attempts = 0
            attempt.window_started_at = now
            attempt.blocked_until = None
        attempt.failed_attempts += 1
        if attempt.failed_attempts >= MAX_INVITE_FAILURES:
            attempt.blocked_until = now + INVITE_BLOCK_DURATION
        attempt.save(update_fields=["failed_attempts", "window_started_at", "blocked_until"])
    InviteCodeAttempt.objects.filter(window_started_at__lt=now - timedelta(days=14)).filter(
        Q(blocked_until__lt=now) | Q(blocked_until__isnull=True),
    ).delete()
    return attempt.blocked_until


def _normalized_profile_image(upload):
    if upload.size > MAX_PROFILE_IMAGE_BYTES:
        raise ValueError("Choose an image no larger than 10 MB.")
    try:
        upload.seek(0)
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(upload) as checked:
                if checked.format not in {"BMP", "GIF", "HEIC", "HEIF", "ICO", "JPEG", "PNG", "PPM", "TIFF", "WEBP"}:
                    raise ValueError("Choose a standard image file such as JPEG, PNG, WebP, or HEIC.")
                checked.verify()
                width, height = checked.size
                if width < 1 or height < 1 or width * height > MAX_PROFILE_IMAGE_PIXELS:
                    raise ValueError("That image is too large to process.")
        upload.seek(0)
        with Image.open(upload) as source:
            source.draft("RGB", (512, 512))
            source.seek(0)
            image = ImageOps.exif_transpose(source.copy())
        edge = min(image.width, image.height)
        left = (image.width - edge) // 2
        top = (image.height - edge) // 2
        image = image.crop((left, top, left + edge, top + edge))
        image = image.resize((512, 512), Image.Resampling.LANCZOS)
        if image.mode not in {"RGB", "RGBA"}:
            image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
        output = io.BytesIO()
        image.save(output, format="WEBP", quality=84, method=5)
        return ContentFile(output.getvalue(), name="image.webp")
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
        raise ValueError("That file could not be read as a safe image.") from error


def _member_profile(user):
    profile, _ = MemberProfile.objects.get_or_create(
        user=user,
        defaults={
            "display_name": f"Player {user.pk:03d}",
        },
    )
    return profile


def _create_invitation(*, username="", creator, is_admin=False, is_recovery=False):
    selector = uuid.uuid4()
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        secret_code = "".join(secrets.choice(alphabet) for _ in range(16 if is_recovery else 8))
        if not Invitation.objects.filter(invitation_code_digest=_digest(secret_code)).exists():
            break
    code = secret_code
    username_assigned = True
    if not username:
        while True:
            username = f"player-{''.join(secrets.choice(alphabet).lower() for _ in range(6))}"
            if not User.objects.filter(username__iexact=username).exists() and not Invitation.objects.filter(
                username__iexact=username,
                is_recovery=False,
                used_at__isnull=True,
                revoked_at__isnull=True,
                expires_at__gt=timezone.now(),
            ).exists():
                break
    invitation = Invitation.objects.create(
        selector=selector,
        username=username,
        invitation_code_digest=_digest(code),
        invitation_code_ciphertext=_encrypt_invitation_code(code),
        username_assigned=username_assigned,
        is_admin=is_admin,
        is_recovery=is_recovery,
        created_by_username=creator,
        expires_at=timezone.now() + INVITE_LIFETIME,
    )
    return invitation, code


def _invitation_url(request, invitation):
    return request.build_absolute_uri(reverse("enroll", args=[invitation.selector]))


def _show_invitation_code(request, invitation, code):
    request.session["created_invitation_result"] = {
        "selector": str(invitation.selector),
        "code": code,
        "expires": time.time() + 600,
    }
    return redirect("invite_created")


def _bytes_label(value):
    amount = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if amount < 1000 or unit == "TB":
            return f"{amount:.1f} {unit}" if unit != "B" else f"{int(amount)} B"
        amount /= 1000
    return f"{amount:.1f} TB"


def _month_id(record):
    stamp = record.get("date") or record.get("id") or {}
    if not isinstance(stamp, dict):
        return None
    try:
        return int(stamp["year"]), int(stamp["month"])
    except (KeyError, TypeError, ValueError):
        return None


def _bandwidth_stats():
    try:
        result = subprocess.run(
            [VNSTAT_PATH, "-i", MONITORED_INTERFACE, "--json", "m", "12"],
            check=True,
            capture_output=True,
            text=True,
            timeout=4,
        )
        data = json.loads(result.stdout)
        interface = next(
            item for item in data.get("interfaces", [])
            if item.get("name") == MONITORED_INTERFACE
        )
    except (OSError, subprocess.SubprocessError, ValueError, StopIteration):
        return {"available": False, "message": "Traffic totals are initializing. Check again after the first collection interval."}

    months = []
    for record in interface.get("traffic", {}).get("month", []):
        month_id = _month_id(record)
        if not month_id:
            continue
        year, month = month_id
        rx_bytes = int(record.get("rx", 0))
        tx_bytes = int(record.get("tx", 0))
        months.append({
            "year": year,
            "month_number": month,
            "label": f"{year}-{month:02d}",
            "rx_bytes": rx_bytes,
            "tx_bytes": tx_bytes,
            "total_bytes": rx_bytes + tx_bytes,
            "rx": _bytes_label(rx_bytes),
            "tx": _bytes_label(tx_bytes),
            "total": _bytes_label(rx_bytes + tx_bytes),
        })

    months.sort(key=lambda row: (row["year"], row["month_number"]))
    max_total = max((row["total_bytes"] for row in months), default=0)
    for row in months:
        if max_total:
            row["rx_units"] = round(row["rx_bytes"] * 1000 / max_total)
            row["tx_units"] = round(row["tx_bytes"] * 1000 / max_total)
        else:
            row["rx_units"] = row["tx_units"] = 0

    created = interface.get("created", {}).get("date", {})
    since = None
    if isinstance(created, dict) and created.get("year") and created.get("month"):
        since = f"{created['year']}-{int(created['month']):02d}"
    return {
        "available": True,
        "interface": MONITORED_INTERFACE,
        "months": months,
        "current": months[-1] if months else None,
        "since": since,
        "message": None if months else "Traffic totals are initializing. Check again after the first collection interval.",
    }


def _server_stats():
    memory_total = memory_available = 0
    try:
        with open("/proc/meminfo", encoding="ascii") as stream:
            for line in stream:
                key, value = line.split(":", 1)
                if key in {"MemTotal", "MemAvailable"}:
                    amount = int(value.strip().split()[0]) * 1024
                    if key == "MemTotal":
                        memory_total = amount
                    else:
                        memory_available = amount
    except (OSError, ValueError):
        pass

    try:
        with open("/proc/loadavg", encoding="ascii") as stream:
            load = stream.read().split()[:3]
    except OSError:
        load = []

    try:
        with open("/proc/uptime", encoding="ascii") as stream:
            uptime_seconds = int(float(stream.read().split()[0]))
    except (OSError, ValueError, IndexError):
        uptime_seconds = 0

    disk = shutil.disk_usage("/")
    memory_used = max(memory_total - memory_available, 0)
    return {
        "load": " / ".join(load) if load else "Unavailable",
        "memory_used": _bytes_label(memory_used),
        "memory_total": _bytes_label(memory_total),
        "memory_percent": round(memory_used * 100 / memory_total) if memory_total else 0,
        "disk_used": _bytes_label(disk.used),
        "disk_total": _bytes_label(disk.total),
        "disk_percent": round(disk.used * 100 / disk.total) if disk.total else 0,
        "uptime_days": uptime_seconds // 86400,
        "uptime_hours": (uptime_seconds % 86400) // 3600,
    }


def _backup_status():
    try:
        record = json.loads(settings.PRIVATE_BACKUP_STATUS_PATH.read_text(encoding="utf-8"))
        if not isinstance(record, dict):
            raise ValueError("invalid backup status")
    except (OSError, ValueError):
        record = {}

    def parse_timestamp(value):
        if not value:
            return None
        try:
            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except ValueError:
            return None
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=datetime_timezone.utc)

    last_success = parse_timestamp(record.get("last_success_at"))
    last_failure = parse_timestamp(record.get("last_failure_at"))
    if not last_success:
        label = "No restore point"
        last_success_label = "No successful backup yet"
    elif last_failure and last_failure > last_success:
        label = "Needs attention"
        last_success_label = timezone.localtime(last_success).strftime("%Y-%m-%d %H:%M Detroit")
    elif timezone.now() - last_success > timedelta(hours=36):
        label = "Overdue"
        last_success_label = timezone.localtime(last_success).strftime("%Y-%m-%d %H:%M Detroit")
    else:
        label = "Current"
        last_success_label = timezone.localtime(last_success).strftime("%Y-%m-%d %H:%M Detroit")

    try:
        retained_count = max(0, int(record.get("retained_count", 0)))
        size_bytes = max(0, int(record.get("last_success_size_bytes", 0)))
    except (TypeError, ValueError):
        retained_count = size_bytes = 0
    return {
        "label": label,
        "last_success": last_success_label,
        "retained_count": retained_count,
        "size": _bytes_label(size_bytes) if last_success else "—",
    }


def _month_label(period):
    return period.strftime("%Y-%m")


def _active_account_sessions(request):
    active_logins, active_session_digests = active_login_sessions(request.session.session_key)
    close_missing_sessions(active_session_digests)
    current_ip = request_ip_address(request)
    current_user_agent = request_user_agent(request)
    observed_at = timezone.now()
    for active_login in active_logins:
        active_login["observed_ip"] = current_ip if active_login["is_current"] else None
        active_login["observed_user_agent"] = current_user_agent if active_login["is_current"] else ""
        active_login["observed_at"] = observed_at if active_login["is_current"] else None
    return active_logins, active_session_digests


def _decorate_history(history, active_session_digests):
    for event in history.object_list:
        if event.event_type == LoginEvent.LOGIN_FAILED:
            event.display_status = "Failed"
            event.display_status_class = "status-bad"
        elif event.ended_at is None and event.session_key_digest in active_session_digests:
            event.display_status = "Active"
            event.display_status_class = "status-active"
        elif event.end_reason == LoginEvent.END_SIGNED_OUT:
            event.display_status = "Signed out"
            event.display_status_class = "status-neutral"
        else:
            event.display_status = "Session ended"
            event.display_status_class = "status-neutral"


def _account_rows(active_logins):
    sessions_by_user = {}
    for active_login in active_logins:
        sessions_by_user.setdefault(active_login["user_id"], []).append(active_login)

    users = list(User.objects.order_by("username").prefetch_related("passkeys"))
    passkey_accounts = {
        account.user_id: account
        for account in PasskeyAccount.objects.filter(user_id__in=[user.pk for user in users])
    }
    rows = []
    for user in users:
        user_sessions = sessions_by_user.get(user.pk, [])
        passkey_account = passkey_accounts.get(user.pk)
        user.username_set = True
        user.has_passkey = bool(user.passkeys.all())
        profile = _member_profile(user)
        user.is_site_persona = profile.is_site_persona
        user.setup_pending = not user.has_passkey and not user.is_site_persona
        user.display_name = profile.display_name
        user.account_profile = profile
        user.role_label = "Site persona" if user.is_site_persona else "Owner" if user.is_superuser else "Staff" if user.is_staff else "Member"
        user.active_sessions = user_sessions
        user.device_count = len(user_sessions)
        rows.append(user)
    return rows


def home(request):
    if request.user.is_authenticated:
        return redirect("spcboy")
    return redirect("login")


@login_required
@never_cache
@require_safe
def bom_home(request):
    if not request.user.is_superuser:
        raise PermissionDenied
    return redirect("bom_asset", asset_path="Sites/V4/reader.html")


@login_required
@never_cache
@require_safe
def bom_asset(request, asset_path):
    if not request.user.is_superuser:
        raise PermissionDenied

    if "\\" in asset_path or "\x00" in asset_path:
        raise Http404
    relative_path = PurePosixPath(asset_path)
    if relative_path.is_absolute() or any(part in {".", ".."} for part in relative_path.parts):
        raise Http404

    root = (Path(settings.BASE_DIR) / "bom_site").resolve()
    try:
        target = (root / Path(*relative_path.parts)).resolve(strict=True)
    except (OSError, RuntimeError):
        raise Http404
    if not target.is_relative_to(root) or not target.is_file():
        raise Http404

    content_type, _encoding = mimetypes.guess_type(target.name)
    response = FileResponse(target.open("rb"), content_type=content_type or "application/octet-stream")
    response["Cache-Control"] = "private, no-store"
    response["X-Content-Type-Options"] = "nosniff"
    return response


@login_required
def dashboard(request):
    return redirect("accounts")


@never_cache
@login_required
def spcboy(request):
    return render(request, "accounts/spcboy.html", {"member_profile": _member_profile(request.user)})


@login_required
@never_cache
@require_http_methods(["GET", "POST"])
def spcboy_preferences(request):
    profile = _member_profile(request.user)
    headers = {"Cache-Control": "private, no-store"}
    if request.method == "GET":
        preferences = profile.spcboy_preferences if isinstance(profile.spcboy_preferences, dict) else {}
        return JsonResponse({"preferences": preferences}, headers=headers)
    if len(request.body) > 1_500_000:
        return JsonResponse({"error": "Player preferences are too large."}, status=413, headers=headers)
    try:
        payload = json.loads(request.body)
    except (UnicodeDecodeError, ValueError):
        return JsonResponse({"error": "Player preferences could not be read."}, status=400, headers=headers)
    if not isinstance(payload, dict):
        return JsonResponse({"error": "Player preferences are invalid."}, status=400, headers=headers)
    try:
        json.dumps(payload, allow_nan=False)
    except (TypeError, ValueError, RecursionError):
        return JsonResponse({"error": "Player preference data is invalid."}, status=400, headers=headers)

    scopes = {"player", "interface", "library", "playback"}
    for section_name in ("imports", "updates", "removals"):
        section = payload.get(section_name, {})
        if not isinstance(section, dict) or any(scope not in scopes for scope in section):
            return JsonResponse({"error": "Player preference data is invalid."}, status=400, headers=headers)
        for scope, values in section.items():
            if section_name == "removals":
                if not isinstance(values, list) or any(not isinstance(key, str) or not key or len(key) > 64 for key in values):
                    return JsonResponse({"error": "Player preference data is invalid."}, status=400, headers=headers)
            elif not isinstance(values, dict) or any(not isinstance(key, str) or not key or len(key) > 64 for key in values):
                return JsonResponse({"error": "Player preference data is invalid."}, status=400, headers=headers)
    if any(key not in {"imports", "updates", "removals"} for key in payload):
        return JsonResponse({"error": "Player preference data is invalid."}, status=400, headers=headers)

    with transaction.atomic():
        profile = MemberProfile.objects.select_for_update().get(pk=profile.pk)
        preferences = profile.spcboy_preferences if isinstance(profile.spcboy_preferences, dict) else {}
        preferences = {scope: dict(values) for scope, values in preferences.items() if isinstance(values, dict)}
        for scope, values in payload.get("imports", {}).items():
            target = preferences.setdefault(scope, {})
            for key, value in values.items():
                target.setdefault(key, value)
        for scope, values in payload.get("updates", {}).items():
            preferences.setdefault(scope, {}).update(values)
        for scope, keys in payload.get("removals", {}).items():
            target = preferences.setdefault(scope, {})
            for key in keys:
                target.pop(key, None)
            if not target:
                preferences.pop(scope, None)
        profile.spcboy_preferences = preferences
        profile.save(update_fields=["spcboy_preferences"])
    return JsonResponse({"preferences": preferences}, headers=headers)


@login_required
@never_cache
@require_http_methods(["GET", "POST"])
def spcboy_favorites(request):
    if request.method == "GET":
        favorite_ids = list(FavoriteTrack.objects.filter(user=request.user).values_list("track_id", flat=True))
        album_ids = list(FavoriteAlbum.objects.filter(user=request.user).values_list("album_id", flat=True))
        return JsonResponse({
            "trackIds": favorite_ids,
            "albumIds": album_ids,
        }, headers={"Cache-Control": "private, no-store"})
    try:
        payload = json.loads(request.body)
    except (UnicodeDecodeError, ValueError):
        return JsonResponse({"error": "Favorite data could not be read."}, status=400)
    if not isinstance(payload, dict):
        return JsonResponse({"error": "Favorite data is invalid."}, status=400)
    catalog = _spcboy_catalog_data()
    if catalog is None:
        return JsonResponse({"error": "The SPCBOY library is not available."}, status=503)
    if "removeTrackIds" in payload or "removeAlbumIds" in payload:
        requested = payload.get("removeTrackIds", [])
        requested_albums = payload.get("removeAlbumIds", [])
        if not isinstance(requested, list) or len(requested) > 2000 or any(
            not isinstance(item, str) or not item or len(item) > 64 for item in requested
        ):
            return JsonResponse({"error": "Select between 1 and 2,000 favorite tracks."}, status=400)
        if not isinstance(requested_albums,list) or len(requested_albums)>1000 or any(
            not isinstance(item,str) or len(item)!=32 for item in requested_albums
        ) or not (requested or requested_albums):
            return JsonResponse({"error":"Select favorite tracks or albums to remove."},status=400)
        removed_albums=set(requested_albums)
        if not removed_albums.issubset(_catalog_album_index(catalog)):
            return JsonResponse({"error":"A selected album is no longer available. Reload Favorites."},status=409)
        removed = set(requested)
        if not removed.issubset(catalog["tracks"]):
            return JsonResponse({"error": "A selected track is no longer available. Reload Favorites."}, status=409)
        affected_albums = {}
        for console in catalog["consoles"]:
            for game in console.get("games", []):
                ids = list(dict.fromkeys(str(track["id"]) for track in game.get("tracks", []) if isinstance(track, dict) and track.get("id")))
                if set(ids) & removed:
                    album_id = spcboy_album_id(str(console.get("name", "")), str(game.get("name", "")))
                    affected_albums[album_id] = [track_id for track_id in ids if track_id not in removed]
        with transaction.atomic():
            # Take SQLite's write lock before reading/converting album memberships.
            FavoriteTrack.objects.filter(user=request.user, track_id__in=removed).delete()
            FavoriteAlbum.objects.filter(user=request.user, album_id__in=removed_albums).delete()
            albums = FavoriteAlbum.objects.filter(user=request.user, album_id__in=affected_albums)
            for album in albums:
                # Preserve every unselected song and the album's original favorite order.
                FavoriteTrack.objects.bulk_create([
                    FavoriteTrack(user=request.user, track_id=track_id, added_at=album.added_at)
                    for track_id in affected_albums[album.album_id]
                ], ignore_conflicts=True)
            albums.delete()
        return JsonResponse({
            "trackIds": list(FavoriteTrack.objects.filter(user=request.user).values_list("track_id", flat=True)),
            "albumIds": list(FavoriteAlbum.objects.filter(user=request.user).values_list("album_id", flat=True)),
        }, headers={"Cache-Control": "private, no-store"})
    if "trackId" in payload:
        track_id = payload.get("trackId")
        favorite = payload.get("favorite")
        if not isinstance(track_id, str) or len(track_id) > 64 or not isinstance(favorite, bool):
            return JsonResponse({"error": "Favorite action is invalid."}, status=400)
        if track_id not in _catalog_track_index(catalog):
            return JsonResponse({"error": "That track is not in the hosted library."}, status=404)
        if favorite:
            FavoriteTrack.objects.get_or_create(user=request.user, track_id=track_id)
        else:
            FavoriteTrack.objects.filter(user=request.user, track_id=track_id).delete()
        return JsonResponse({"favorite": favorite}, headers={"Cache-Control": "private, no-store"})
    if "albumId" in payload:
        album_id = payload.get("albumId")
        favorite = payload.get("favorite")
        if not isinstance(album_id, str) or len(album_id) != 32 or not isinstance(favorite, bool):
            return JsonResponse({"error": "Album favorite action is invalid."}, status=400)
        if album_id not in _catalog_album_index(catalog):
            return JsonResponse({"error": "That album is not in the hosted library."}, status=404)
        if favorite:
            FavoriteAlbum.objects.get_or_create(user=request.user, album_id=album_id)
        else:
            FavoriteAlbum.objects.filter(user=request.user, album_id=album_id).delete()
        return JsonResponse({"favorite": favorite}, headers={"Cache-Control": "private, no-store"})
    if not any(key in payload for key in ("trackIds", "albumIds")):
        return JsonResponse({"error": "Favorite data is invalid."}, status=400)
    target_tracks = None
    if "trackIds" in payload:
        requested_tracks = payload["trackIds"]
        if not isinstance(requested_tracks, list) or len(requested_tracks) > 50_000 or any(
            not isinstance(item, str) or len(item) > 64 for item in requested_tracks
        ):
            return JsonResponse({"error": "Favorite track list is too large or invalid."}, status=400)
        valid_track_ids = _catalog_track_index(catalog)
        target_tracks = {item for item in requested_tracks if item in valid_track_ids}
    target_albums = None
    if "albumIds" in payload:
        requested_albums = payload["albumIds"]
        if not isinstance(requested_albums, list) or len(requested_albums) > 2000 or any(
            not isinstance(item, str) or len(item) != 32 for item in requested_albums
        ):
            return JsonResponse({"error": "Favorite album list is too large or invalid."}, status=400)
        valid_album_ids = _catalog_album_index(catalog)
        target_albums = {item for item in requested_albums if item in valid_album_ids}

    with transaction.atomic():
        if target_tracks is not None:
            existing_tracks = set(FavoriteTrack.objects.filter(user=request.user).values_list("track_id", flat=True))
            FavoriteTrack.objects.filter(user=request.user, track_id__in=existing_tracks - target_tracks).delete()
            FavoriteTrack.objects.bulk_create([
                FavoriteTrack(user=request.user, track_id=track_id)
                for track_id in target_tracks - existing_tracks
            ], ignore_conflicts=True)
        if target_albums is not None:
            existing_albums = set(FavoriteAlbum.objects.filter(user=request.user).values_list("album_id", flat=True))
            FavoriteAlbum.objects.filter(user=request.user, album_id__in=existing_albums - target_albums).delete()
            FavoriteAlbum.objects.bulk_create([
                FavoriteAlbum(user=request.user, album_id=album_id)
                for album_id in target_albums - existing_albums
            ], ignore_conflicts=True)
        if "trackIds" in payload and "albumIds" in payload:
            profile = MemberProfile.objects.select_for_update().get(pk=_member_profile(request.user).pk)
            preferences = profile.spcboy_preferences if isinstance(profile.spcboy_preferences, dict) else {}
            library_preferences = preferences.get("library")
            if isinstance(library_preferences, dict):
                library_preferences = dict(library_preferences)
                library_preferences.pop("favorites", None)
                library_preferences.pop("favoriteAlbums", None)
                if library_preferences:
                    preferences["library"] = library_preferences
                else:
                    preferences.pop("library", None)
                profile.spcboy_preferences = preferences
                profile.save(update_fields=["spcboy_preferences"])
    response = {
        "trackIds": sorted(target_tracks if target_tracks is not None else FavoriteTrack.objects.filter(
            user=request.user,
        ).values_list("track_id", flat=True)),
        "albumIds": sorted(target_albums if target_albums is not None else FavoriteAlbum.objects.filter(
            user=request.user,
        ).values_list("album_id", flat=True)),
    }
    return JsonResponse(response, headers={"Cache-Control": "private, no-store"})


def _active_now_playing():
    return list(
        SPCBOYNowPlaying.objects.select_related("user", "user__member_profile")
        .filter(
            user__is_active=True,
            user__passkeys__isnull=False,
            updated_at__gte=timezone.now() - NOW_PLAYING_TTL,
        )
        .distinct()
    )


@login_required
@never_cache
@require_GET
def listening_now_playing(request):
    catalog = _catalog_track_index(_spcboy_catalog_data())
    artwork_index = _spcboy_gallery_index()
    now_playing = _active_now_playing()
    now_playing.sort(key=lambda item: (-item.started_at.timestamp(), item.user_id))
    members = []
    for active in now_playing:
        active_track = catalog.get(active.track_id, {})
        profile = active.user.member_profile
        current_play = {
            "trackId": active.track_id,
            "title": active.title,
            "game": active.game,
            "console": active.console,
            "startedAt": active.started_at.isoformat(),
            "artist": active_track.get("artist", ""),
            "durationSeconds": active_track.get("durationSeconds", 0),
            "artworkUrl": _track_artwork_url(active_track, artwork_index),
            "albumPlaylistUrl": active_track.get("albumPlaylistUrl", ""),
        }
        members.append({
            "userId": active.user_id,
            "displayName": profile.display_name,
            "avatarUrl": profile.avatar_url,
            "initials": profile.initials,
            "profileUrl": reverse("member_public_profile", args=[active.user_id]),
            "nowPlaying": current_play,
            "cardHtml": render_to_string("accounts/partials/track_card.html", {
                "track_id": active.track_id, "track_title": active.title,
                "track_game": active.game, "track_console": active.console,
                "track_artist": active_track.get("artist", ""),
                "track_duration": active_track.get("durationSeconds", 0),
                "artwork_url": current_play["artworkUrl"], "card_profile": profile,
                "card_album_url": active_track.get("albumPlaylistUrl", ""),
                "card_profile_url": reverse("member_public_profile", args=[active.user_id]),
                "card_time": active.started_at, "card_time_label": "Since ",
            }, request=request),
        })
    return JsonResponse({"members": members, "onlineCount": online_user_count()}, headers={"Cache-Control": "private, no-store"})


def _latest_played_activity_id():
    return SPCBOYPlaybackHistory.objects.filter(user__is_active=True).aggregate(
        latest_id=Max("pk"),
    )["latest_id"] or 0


def _activity_read_state(user):
    state = MemberActivityReadState.objects.filter(user=user).first()
    if state:
        return state
    state, _ = MemberActivityReadState.objects.get_or_create(
        user=user,
        defaults={"played_last_seen_id": _latest_played_activity_id()},
    )
    return state


def _mark_played_activity_read(user, latest_id=None):
    if latest_id is None:
        latest_id = _latest_played_activity_id()
    state = _activity_read_state(user)
    MemberActivityReadState.objects.filter(pk=state.pk).update(
        played_last_seen_id=Greatest(F("played_last_seen_id"), Value(latest_id)),
    )


@login_required
@never_cache
@require_GET
def activity_badges(request):
    state = _activity_read_state(request.user)
    counts = {
        "played": SPCBOYPlaybackHistory.objects.filter(
            pk__gt=state.played_last_seen_id,
            user__is_active=True,
        ).exclude(user=request.user).count(),
    }
    return JsonResponse({"counts": counts}, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_http_methods(["GET", "POST"])
def member_profile(request):
    profile = _member_profile(request.user)
    profile_tab = request.GET.get("tab", "account")
    allowed_tabs = {"account", "favorites", "recents", "security"}
    site_action = request.method == "POST" and request.POST.get("action") == "site-settings"
    if profile_tab == "site" or site_action:
        if not request.user.is_superuser:
            raise PermissionDenied
        return accounts(request) if site_action else redirect("accounts")
    if profile_tab not in allowed_tabs:
        profile_tab = "account"
    form = MemberProfileForm(
        request.POST if request.method == "POST" and not site_action else None,
        request.FILES or None,
        user=request.user,
        initial={
            "display_name": profile.display_name,
            "theme_preference": profile.theme_preference,
        },
    )
    if request.method == "POST" and not site_action and form.is_valid():
        avatar = form.cleaned_data["avatar"]
        remove_avatar = form.cleaned_data["remove_avatar"]
        old_avatar = profile.avatar.name
        if avatar:
            try:
                normalized = _normalized_profile_image(avatar)
            except ValueError as error:
                form.add_error("avatar", str(error))
            else:
                profile.avatar.save("profile.webp", normalized, save=False)
        if not form.errors:
            profile.display_name = form.cleaned_data["display_name"]
            profile.theme_preference = form.cleaned_data["theme_preference"]
            if not avatar and remove_avatar:
                profile.avatar = ""
            profile.updated_at = timezone.now()
            profile.save(update_fields=[
                "display_name",
                "avatar",
                "theme_preference",
                "updated_at",
            ])
            if old_avatar and old_avatar != profile.avatar.name:
                default_storage.delete(old_avatar)
            messages.success(request, "Profile saved.")
            return redirect("member_profile")
    catalog_data = _spcboy_catalog_data() or {}
    catalog = _catalog_track_index(catalog_data)
    favorite_rows = [
        {"track": catalog[favorite.track_id], "added_at": favorite.added_at}
        for favorite in FavoriteTrack.objects.filter(user=request.user).order_by("-added_at", "pk")
        if favorite.track_id in catalog
    ]
    artwork_index = _spcboy_gallery_index()
    album_artwork_urls = {}
    for item in favorite_rows:
        item["track"] = _attach_track_artwork(item["track"], artwork_index, album_artwork_urls)
        item["album_playlist_url"] = item["track"].get("albumPlaylistUrl", "")
    favorite_tracks = Paginator(favorite_rows, 50).get_page(request.GET.get("favorite_page"))
    favorite_albums = Paginator(
        _favorite_album_rows(request.user, catalog_data),
        50,
    ).get_page(request.GET.get("album_page"))
    recent_plays = Paginator(
        SPCBOYPlaybackHistory.objects.filter(user=request.user).order_by("-played_at", "-pk"),
        50,
    ).get_page(request.GET.get("recent_page"))
    bandwidth = _profile_bandwidth(request.user)
    for play in recent_plays:
        track = catalog.get(play.track_id, {})
        play.artist = track.get("artist", "")
        play.duration_seconds = track.get("durationSeconds", 0)
        play.artwork_url = _track_artwork_url(track, artwork_index)
        play.album_playlist_url = track.get("albumPlaylistUrl", "")
    return render(request, "accounts/profile.html", {
        "form": form,
        "member_profile": profile,
        "joined_at": request.user.date_joined,
        "favorite_tracks": favorite_tracks,
        "favorite_albums": favorite_albums,
        "recent_plays": recent_plays,
        "bandwidth": bandwidth,
        "login_password": AccessKeyCredential.objects.filter(user=request.user).first(),
        "passkeys": request.user.passkeys.all(),
        "profile_tab": profile_tab,
    })


@login_required
@never_cache
@require_POST
def generate_login_password(request):
    key = secrets.token_urlsafe(32)
    previous_key = AccessKeyCredential.objects.filter(user=request.user).first()
    AccessKeyCredential.objects.update_or_create(
        user=request.user,
        defaults={
            "key_digest": _access_key_digest(key),
            "created_at": timezone.now(),
            "last_used_at": None,
        },
    )
    return render(request, "accounts/login_password_created.html", {
        "login_password": key,
        "replaced": previous_key is not None,
    })


@login_required
@never_cache
@require_POST
def revoke_login_password(request):
    AccessKeyCredential.objects.filter(user=request.user).delete()
    messages.success(request, "Generated login password revoked.")
    return redirect("member_profile")


@login_required
@never_cache
@require_GET
def member_public_profile(request, user_id):
    user = get_object_or_404(
        User.objects.filter(is_active=True).filter(
            Q(passkeys__isnull=False) | Q(member_profile__is_site_persona=True)
        ).distinct(),
        pk=user_id,
    )
    profile = _member_profile(user)
    profile_tab = request.GET.get("tab", "favorites")
    if profile_tab not in {"favorites", "recents"}:
        profile_tab = "favorites"
    catalog_data = _spcboy_catalog_data() or {}
    catalog = _catalog_track_index(catalog_data)
    favorite_rows = [
        {"track": catalog[favorite.track_id], "added_at": favorite.added_at}
        for favorite in FavoriteTrack.objects.filter(user=user).order_by("-added_at", "pk")
        if favorite.track_id in catalog
    ]
    artwork_index = _spcboy_gallery_index()
    album_artwork_urls = {}
    for item in favorite_rows:
        item["track"] = _attach_track_artwork(item["track"], artwork_index, album_artwork_urls)
        item["album_playlist_url"] = item["track"].get("albumPlaylistUrl", "")
    recent_plays = Paginator(
        SPCBOYPlaybackHistory.objects.filter(user=user).order_by("-played_at", "-pk"),
        50,
    ).get_page(request.GET.get("recent_page"))
    bandwidth = _profile_bandwidth(user)
    for play in recent_plays:
        track = catalog.get(play.track_id, {})
        play.artist = track.get("artist", "")
        play.duration_seconds = track.get("durationSeconds", 0)
        play.artwork_url = _track_artwork_url(track, artwork_index)
        play.album_playlist_url = track.get("albumPlaylistUrl", "")
    return render(request, "accounts/public_profile.html", {
        "profile_user": user,
        "member_profile": profile,
        "joined_at": user.date_joined,
        "favorite_tracks": Paginator(favorite_rows, 50).get_page(request.GET.get("favorite_page")),
        "favorite_albums": Paginator(
            _favorite_album_rows(user, catalog_data),
            50,
        ).get_page(request.GET.get("album_page")),
        "recent_plays": recent_plays,
        "bandwidth": bandwidth,
        "profile_tab": profile_tab,
    })


def _profile_bandwidth(user):
    rows = []
    site_total = 0
    media_total = 0
    audio_total = 0
    for usage in MonthlyUsage.objects.filter(user=user).order_by("-period"):
        site_total += usage.site_bytes
        media_total += usage.media_bytes
        audio_total += usage.audio_bytes
        rows.append({
            "period": usage.period,
            "site_bytes": _bytes_label(usage.site_bytes),
            "media_bytes": _bytes_label(usage.media_bytes),
            "audio_bytes": _bytes_label(usage.audio_bytes),
            "audio_allowance": _bytes_label(MONTHLY_AUDIO_STREAM_LIMIT_BYTES),
            "total_bytes": _bytes_label(usage.site_bytes + usage.media_bytes),
        })
    return {
        "rows": rows,
        "site_total": _bytes_label(site_total),
        "media_total": _bytes_label(media_total),
        "audio_total": _bytes_label(audio_total),
        "total": _bytes_label(site_total + media_total),
    }


@login_required
@require_GET
def community_media(request, object_path):
    if ".." in object_path or not object_path.startswith("avatars/"):
        raise PermissionDenied
    is_profile_image = MemberProfile.objects.filter(avatar=object_path, user__is_active=True).exists()
    if not is_profile_image or not default_storage.exists(object_path):
        return HttpResponseGone("That community image is no longer available.")
    try:
        image_file = default_storage.open(object_path, "rb")
    except OSError:
        return HttpResponseGone("That community image is no longer available.")
    response = FileResponse(image_file, content_type="image/webp")
    response["Cache-Control"] = "private, max-age=300"
    response["X-Content-Type-Options"] = "nosniff"
    return response


@login_required
@require_GET
def spcboy_catalog(request):
    catalog = _spcboy_catalog_data()
    if catalog is None:
        return JsonResponse({"error": "The SPCBOY trial library is not installed yet."}, status=503)
    public_consoles = []
    cached_artwork = _spcboy_gallery_index()
    for console in catalog["consoles"]:
        public_console = {"name": str(console.get("name", "")), "games": []}
        for game in console.get("games", []):
            game_name = str(game.get("name", ""))
            album_id = spcboy_album_id(public_console["name"], game_name)
            public_game = {
                "name": game_name,
                "albumId": album_id,
                "artworkUrl": _spcboy_artwork_url(album_id, cached_artwork),
                "detailArtworkUrl": _spcboy_artwork_url(album_id, cached_artwork, detail=True),
                "trackCount": sum(1 for track in game.get("tracks", []) if isinstance(track, dict) and track.get("id")),
            }
            public_console["games"].append(public_game)
        public_consoles.append(public_console)
    return JsonResponse({"consoles": public_consoles}, headers={"Cache-Control": "private, no-store"})


@login_required
@require_GET
def spcboy_album_playlist(request, album_id):
    if len(album_id) != 32 or any(character not in "0123456789abcdef" for character in album_id):
        raise Http404
    catalog = _spcboy_catalog_data()
    if catalog is None:
        return JsonResponse({"error": "The SPCBOY library is not available."}, status=503)
    metadata_by_id = catalog["tracks"]
    for console in catalog["consoles"]:
        console_name = str(console.get("name", ""))
        for game in console.get("games", []):
            game_name = str(game.get("name", ""))
            if spcboy_album_id(console_name, game_name) != album_id:
                continue
            public_tracks = []
            for track in game.get("tracks", []):
                if not isinstance(track, dict) or not track.get("id"):
                    continue
                track_id = str(track["id"])
                metadata = metadata_by_id.get(track_id, {})
                if not isinstance(metadata, dict):
                    metadata = {}
                public_tracks.append(_public_spcboy_track(track, metadata, game_name, console_name))
            if public_tracks:
                return JsonResponse({
                    "albumId": album_id,
                    "name": game_name,
                    "console": console_name,
                    "tracks": public_tracks,
                }, headers={"Cache-Control": "private, no-store"})
            break
    raise Http404


@login_required
@never_cache
@require_GET
def spcboy_track_detail(request, track_id):
    catalog = _spcboy_catalog_data()
    track = _catalog_track_index(catalog).get(track_id) if catalog else None
    if track is None:
        raise Http404
    album_id = spcboy_album_id(track["console"], track["game"])
    track = {
        **track,
        "albumId": album_id,
        "artworkUrl": _spcboy_artwork_url(album_id),
    }
    return JsonResponse({"track": track}, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_GET
def spcboy_favorite_playlist(request):
    catalog = _spcboy_catalog_data()
    if catalog is None:
        return JsonResponse({"error": "The SPCBOY trial library is not installed yet."}, status=503)
    try:
        page_number = max(1, int(request.GET.get("page", "1")))
    except (TypeError, ValueError):
        page_number = 1
    page_size = 100
    offset = (page_number - 1) * page_size
    favorite_dates = dict(
        FavoriteTrack.objects.filter(user=request.user).values_list("track_id", "added_at")
    )
    favorite_album_dates = dict(
        FavoriteAlbum.objects.filter(user=request.user).values_list("album_id", "added_at")
    )
    metadata_by_id = catalog["tracks"]
    matching = []
    catalog_order = 0
    matching_count = 0
    for console in catalog["consoles"]:
        console_name = str(console.get("name", ""))
        for game in console.get("games", []):
            game_name = str(game.get("name", ""))
            album_id = spcboy_album_id(console_name, game_name)
            album_added_at = favorite_album_dates.get(album_id)
            for track in game.get("tracks", []):
                if not isinstance(track, dict) or not track.get("id"):
                    continue
                track_id = str(track["id"])
                track_added_at = favorite_dates.get(track_id)
                added_at = min(
                    (value for value in (track_added_at, album_added_at) if value is not None),
                    default=None,
                )
                if added_at is None:
                    continue
                matching_count += 1
                metadata = metadata_by_id.get(track_id, {})
                if not isinstance(metadata, dict):
                    metadata = {}
                row = _public_spcboy_track(track, metadata, game_name, console_name)
                row["addedAt"] = added_at.isoformat()
                matching.append((added_at, catalog_order, row))
                catalog_order += 1
    matching.sort(key=lambda item: (item[0], item[1]))
    results = [row for _, _, row in matching[offset:offset + page_size]]
    return JsonResponse({
        "tracks": results,
        "nextPage": page_number + 1 if offset + len(results) < matching_count else None,
    }, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_GET
def spcboy_navigation(request):
    track_id = request.GET.get("trackId", "").strip()
    try:
        step = int(request.GET.get("step", "1"))
    except (TypeError, ValueError):
        return JsonResponse({"error": "Track direction is invalid."}, status=400)
    if not track_id or step not in {-1, 1}:
        return JsonResponse({"error": "Track direction is invalid."}, status=400)
    source_path = settings.SPCBOY_MEDIA_ROOT / "catalog.json"
    try:
        if not catalog_index_is_current(settings.SPCBOY_SEARCH_INDEX_PATH, source_path):
            catalog = _spcboy_catalog_data()
            if catalog is None:
                return JsonResponse({"error": "The SPCBOY trial library is not installed yet."}, status=503)
            build_catalog_index(settings.SPCBOY_SEARCH_INDEX_PATH, source_path, catalog)
        track = adjacent_catalog_track(settings.SPCBOY_SEARCH_INDEX_PATH, track_id, step)
    except (OSError, sqlite3.Error, RuntimeError):
        logger.exception("Could not navigate the hosted SPCBOY catalog.")
        return JsonResponse({"error": "The hosted music library is temporarily unavailable."}, status=503)
    if track is None:
        raise Http404
    catalog = _spcboy_catalog_data()
    if catalog:
        track = _public_spcboy_track(track, catalog["tracks"].get(track["id"]), track["game"], track["console"])
    return JsonResponse({"track": track}, headers={"Cache-Control": "private, no-store"})


@login_required
@require_GET
def spcboy_artwork(request, album_id):
    if len(album_id) != 32 or any(character not in "0123456789abcdef" for character in album_id):
        raise Http404
    record = _spcboy_gallery_index().get(album_id)
    size = request.GET.get("size", "thumbnail")
    if size == "detail":
        filename = f"{album_id}-detail{THUMBNAIL_EXTENSION}"
        record_key = "detailFile"
    elif size == "thumbnail":
        filename = f"{album_id}{THUMBNAIL_EXTENSION}"
        record_key = "file"
    else:
        raise Http404
    if not record or record.get(record_key) != filename:
        raise Http404
    image_path = settings.SPCBOY_GALLERY_CACHE_ROOT / filename
    if not image_path.is_file():
        raise Http404
    response = FileResponse(image_path.open("rb"), content_type=THUMBNAIL_MIME_TYPE)
    response["Cache-Control"] = "private, max-age=86400"
    response["X-Content-Type-Options"] = "nosniff"
    return response


@login_required
@never_cache
@require_GET
def spcboy_search(request):
    query = request.GET.get("q", "").strip()
    if len(query) > 160 or len(search_terms(query)) > 20:
        return JsonResponse({"error": "Search with no more than 160 characters or 20 words."}, status=400)
    try:
        page = int(request.GET.get("page", "1"))
    except (TypeError, ValueError):
        return JsonResponse({"error": "Search page is invalid."}, status=400)
    if page < 1 or page > 100_000:
        return JsonResponse({"error": "Search page is invalid."}, status=400)
    source_path = settings.SPCBOY_MEDIA_ROOT / "catalog.json"
    try:
        if not catalog_index_is_current(settings.SPCBOY_SEARCH_INDEX_PATH, source_path):
            catalog = _spcboy_catalog_data()
            if catalog is None:
                return JsonResponse({"error": "The SPCBOY trial library is not installed yet."}, status=503)
            build_catalog_index(settings.SPCBOY_SEARCH_INDEX_PATH, source_path, catalog)
        result = query_catalog_index(settings.SPCBOY_SEARCH_INDEX_PATH, query, page=page)
    except (OSError, sqlite3.Error, RuntimeError):
        logger.exception("Could not search the hosted SPCBOY catalog.")
        return JsonResponse({"error": "The hosted music search is temporarily unavailable."}, status=503)
    catalog = _spcboy_catalog_data()
    if catalog:
        result["results"] = [
            _public_spcboy_track(track, catalog["tracks"].get(track["id"]), track["game"], track["console"])
            for track in result["results"]
        ]
    return JsonResponse(result, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_http_methods(["GET", "POST"])
def spcboy_recents(request):
    if request.method == "POST":
        try:
            payload = json.loads(request.body or b"{}")
        except (json.JSONDecodeError, UnicodeDecodeError):
            return JsonResponse({"error": "Recent play action could not be read."}, status=400)
        event_id = payload.get("hideEventId") if isinstance(payload, dict) else None
        if isinstance(event_id, bool) or not isinstance(event_id, int) or event_id < 1:
            return JsonResponse({"error": "Recent play action is invalid."}, status=400)
        event = SPCBOYPlaybackHistory.objects.filter(pk=event_id, user=request.user).first()
        if event is None:
            return JsonResponse({"error": "That recent play is unavailable."}, status=404)
        SPCBOYRecentHidden.objects.get_or_create(user=request.user, event=event)
        return JsonResponse({"hidden": True}, headers={"Cache-Control": "private, no-store"})

    hidden_event_ids = SPCBOYRecentHidden.objects.filter(user=request.user).values("event_id")
    history = Paginator(
        SPCBOYPlaybackHistory.objects.filter(user=request.user)
        .exclude(pk__in=hidden_event_ids)
        .order_by("-played_at", "-pk"),
        100,
    ).get_page(request.GET.get("page"))
    catalog = _spcboy_catalog_data()
    metadata_by_id = catalog["tracks"] if catalog else {}
    events = list(history.object_list)
    track_ids = {event.track_id for event in events}
    # Retain only this page's public rows; do not build a second full catalog.
    public_rows = {
        track["id"]: track
        for console in (catalog or {}).get("consoles", [])
        for game in console.get("games", [])
        for track in game.get("tracks", [])
        if isinstance(track, dict) and track.get("id") in track_ids
    }
    results = []
    for event in events:
        metadata = metadata_by_id.get(event.track_id)
        results.append({
            **_public_spcboy_track(
                {**public_rows.get(event.track_id, {}), "id": event.track_id, "title": event.title}, metadata,
                event.game, event.console,
            ),
            "eventId": event.pk,
            "trackId": event.track_id,
            "playedAt": event.played_at.isoformat(),
            "available": isinstance(metadata, dict),
        })
    return JsonResponse({
        "results": results,
        "nextPage": history.next_page_number() if history.has_next() else None,
    }, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_POST
def spcboy_now_playing(request):
    try:
        if request.content_type == "application/json":
            payload = json.loads(request.body or b"{}")
        else:
            payload = request.POST
    except (json.JSONDecodeError, UnicodeDecodeError):
        return HttpResponseBadRequest("Invalid now-playing update.")
    if not isinstance(payload, dict) and not hasattr(payload, "get"):
        return HttpResponseBadRequest("Invalid now-playing update.")
    try:
        playback_id = uuid.UUID(str(payload.get("playbackId", "")))
    except (TypeError, ValueError):
        return HttpResponseBadRequest("A playback ID is required.")

    status = payload.get("status")
    if status == "stopped":
        SPCBOYNowPlaying.objects.filter(user=request.user, playback_id=playback_id).delete()
        return JsonResponse({"ok": True}, headers={"Cache-Control": "private, no-store"})
    if status != "playing":
        return HttpResponseBadRequest("Invalid playback status.")

    track_id = str(payload.get("trackId", ""))[:64]
    now = timezone.now()
    # An existing playback was validated on creation. The heartbeat is one
    # atomic UPDATE, without rebuilding the catalog or upgrading a read lock.
    if SPCBOYNowPlaying.objects.filter(
        user=request.user, playback_id=playback_id, track_id=track_id,
    ).update(updated_at=now):
        return JsonResponse({"ok": True}, headers={"Cache-Control": "private, no-store"})
    track = _catalog_track_index(_spcboy_catalog_data()).get(track_id)
    if track is None:
        return HttpResponseBadRequest("Unknown track.")
    # Avoid update_or_create's read-then-write transaction on SQLite when two
    # tabs announce playback concurrently.
    SPCBOYNowPlaying.objects.bulk_create([
        SPCBOYNowPlaying(user=request.user, playback_id=playback_id, track_id=track_id,
            title=str(track.get("title", ""))[:300], game=str(track.get("game", ""))[:300],
            console=str(track.get("console", ""))[:100], started_at=now, updated_at=now),
    ], update_conflicts=True, unique_fields=["user"],
       update_fields=["playback_id","track_id","title","game","console","started_at","updated_at"])
    return JsonResponse({"ok": True}, headers={"Cache-Control": "private, no-store"})


@login_required
@never_cache
@require_GET
def playback_history(request):
    _mark_played_activity_read(request.user)
    today = timezone.localdate()
    yesterday = today - timedelta(days=1)
    current_timezone = timezone.get_current_timezone()

    def start_of_day(day):
        return timezone.make_aware(datetime.combine(day, datetime_time.min), current_timezone)

    today_start = start_of_day(today)
    tomorrow_start = start_of_day(today + timedelta(days=1))
    yesterday_start = start_of_day(yesterday)
    day_filter = request.GET.get("day")
    active_history = SPCBOYPlaybackHistory.objects.filter(user__is_active=True)
    history = SPCBOYPlaybackHistory.objects.select_related("user", "user__member_profile").filter(user__is_active=True)
    if day_filter == "today":
        history = history.filter(played_at__gte=today_start, played_at__lt=tomorrow_start)
    elif day_filter == "yesterday":
        history = history.filter(played_at__gte=yesterday_start, played_at__lt=today_start)
    else:
        day_filter = ""
    daily_totals = active_history.aggregate(
        total=Count("pk"),
        today=Count("pk", filter=Q(played_at__gte=today_start, played_at__lt=tomorrow_start)),
        yesterday=Count("pk", filter=Q(played_at__gte=yesterday_start, played_at__lt=today_start)),
    )
    all_play_count = daily_totals["total"]
    today_play_count = daily_totals["today"]
    yesterday_play_count = daily_totals["yesterday"]
    paginator = Paginator(history.order_by("-played_at", "-pk"), 50)
    paginator.count = {
        "today": today_play_count,
        "yesterday": yesterday_play_count,
        "": all_play_count,
    }[day_filter]
    plays = paginator.get_page(request.GET.get("page"))
    catalog = _catalog_track_index(_spcboy_catalog_data())
    artwork_index = _spcboy_gallery_index()
    now_playing = []
    for active in _active_now_playing():
        track = catalog.get(active.track_id, {})
        active.profile = active.user.member_profile
        active.profile_url = reverse("member_public_profile", args=[active.user_id])
        active.artist = track.get("artist", "")
        active.duration_seconds = track.get("durationSeconds", 0)
        active.artwork_url = _track_artwork_url(track, artwork_index)
        active.album_playlist_url = track.get("albumPlaylistUrl", "")
        now_playing.append(active)
    grouped = {}
    for play in plays:
        day = timezone.localtime(play.played_at).date()
        if day == today:
            label, slug = "Today", "today"
        elif day == yesterday:
            label, slug = "Yesterday", "yesterday"
        else:
            label, slug = day.strftime("%b. %d, %Y"), f"{day:%Y%m%d}"
        group = grouped.setdefault(day, {"label": label, "slug": slug, "items": []})
        track = catalog.get(play.track_id, {})
        play.artist = track.get("artist", "")
        play.duration_seconds = track.get("durationSeconds", 0)
        play.artwork_url = _track_artwork_url(track, artwork_index)
        play.album_playlist_url = track.get("albumPlaylistUrl", "")
        play.profile_url = reverse("member_public_profile", args=[play.user_id])
        group["items"].append({"play": play})
    displayed_days = list(grouped)
    day_counts = {}
    counted_days = [day for day in displayed_days if day not in {today, yesterday}]
    if counted_days:
        day_ranges = Q()
        for day in counted_days:
            day_ranges |= Q(played_at__gte=start_of_day(day), played_at__lt=start_of_day(day + timedelta(days=1)))
        day_counts = {
            row["local_day"]: row["count"]
            for row in active_history.filter(day_ranges).annotate(
                local_day=TruncDate("played_at", tzinfo=current_timezone),
            ).values("local_day").annotate(count=Count("pk"))
        }
    play_days = []
    for day, group in grouped.items():
        if day == today:
            count = today_play_count
        elif day == yesterday:
            count = yesterday_play_count
        else:
            count = day_counts.get(day, 0)
        play_days.append(dict(group, count=count))
    return render(request, "accounts/history.html", {
        "plays": plays,
        "now_playing": now_playing,
        "play_days": play_days,
        "day_filter": day_filter,
        "all_play_count": all_play_count,
        "today_play_count": today_play_count,
        "yesterday_play_count": yesterday_play_count,
        "member_profile": _member_profile(request.user),
    })


def _record_spcboy_playback(user_id, playback_id, track_id, track):
    SPCBOYPlaybackHistory.objects.get_or_create(
        user_id=user_id,
        playback_id=playback_id,
        defaults={
            "track_id": track_id[:64],
            "title": str(track.get("title", ""))[:300],
            "game": str(track.get("game", ""))[:300],
            "console": str(track.get("console", track.get("system", "")))[:100],
        },
    )


def _spcboy_archive_member(track, media_root):
    archive_name = track.get("archive")
    member_name = track.get("member")
    if not isinstance(archive_name, str) or not isinstance(member_name, str):
        return None

    relative_archive = Path(archive_name)
    if relative_archive.is_absolute() or ".." in relative_archive.parts:
        return None
    archive_path = (media_root / relative_archive).resolve()
    if (
        media_root not in archive_path.parents
        or archive_path.suffix.casefold() not in {".zip", ".7z", ".uac"}
        or not archive_path.is_file()
    ):
        return None

    member_path = PurePosixPath(member_name.replace("\\", "/"))
    if member_path.is_absolute() or ".." in member_path.parts or not member_path.parts:
        return None
    normalized_member = "/".join(part for part in member_path.parts if part not in {"", "."})
    member_suffix = PurePosixPath(normalized_member).suffix.casefold()
    if member_suffix not in {".vgm", ".vgz", ".spc", ".nsf", ".nsfe", ".gbs"}:
        return None
    return archive_path, normalized_member, member_suffix


@login_required
@require_GET
def spcboy_audio(request, track_id):
    page_load_token = request.GET.get("pageLoad", "")
    page_session_limit_seconds = LEGACY_PLAYER_SESSION_MAX_AGE_SECONDS
    try:
        page_load_payload = signing.loads(
            page_load_token,
            salt=player_page_load_salt(request.user.pk),
            max_age=PLAYER_SESSION_MAX_AGE_SECONDS,
        )
        if not isinstance(page_load_payload, dict):
            raise ValueError("Invalid playback session token.")
        page_loaded_at = float(page_load_payload["loaded_at"])
        token_limit_seconds = page_load_payload.get("session_limit_seconds")
        if token_limit_seconds is not None:
            if (
                type(token_limit_seconds) is not int
                or token_limit_seconds % 60 != 0
                or not PLAYER_SESSION_LIMIT_MINUTES_MIN * 60
                <= token_limit_seconds
                <= PLAYER_SESSION_LIMIT_MINUTES_MAX * 60
            ):
                raise ValueError("Invalid playback session limit.")
            page_session_limit_seconds = token_limit_seconds
        page_age_seconds = time.time() - page_loaded_at
    except (signing.BadSignature, KeyError, TypeError, ValueError):
        page_age_seconds = PLAYER_SESSION_MAX_AGE_SECONDS
        page_loaded_at = 0
    if page_age_seconds >= page_session_limit_seconds:
        return HttpResponseGone("Reload the page to start another playback session.")

    stream_period = _month_start()
    if audio_stream_remaining(request.user.pk, stream_period) <= 0:
        response = HttpResponse("Monthly audio streaming allowance reached.", status=429)
        response["X-Audio-Quota-Limit"] = str(MONTHLY_AUDIO_STREAM_LIMIT_BYTES)
        response["X-Audio-Quota-Remaining"] = "0"
        return response

    catalog = _spcboy_catalog_data()
    track = catalog.get("tracks", {}).get(track_id) if catalog else None
    if not isinstance(track, dict):
        return HttpResponse(status=404)

    try:
        playback_id = uuid.UUID(request.GET.get("playback", ""))
    except (AttributeError, TypeError, ValueError):
        return HttpResponseBadRequest("A playback ID is required.")

    media_root = settings.SPCBOY_MEDIA_ROOT.resolve()
    selected_member = _spcboy_archive_member(track, media_root)
    if selected_member is None:
        return HttpResponse(status=404)
    archive_path, member_name, member_suffix = selected_member
    if request.GET.get("format", "aac") != "aac":
        return HttpResponseBadRequest("AAC is required. Reload the player to update.")
    bitrate = SiteSettings.objects.filter(pk=1).values_list("aac_bitrate", flat=True).first() or 192
    bitrate = bitrate if bitrate in {96,128,160,192,256} else 192
    stream_encoding_args = ["-c:a", "aac", "-profile:a", "aac_low", "-b:a", f"{bitrate}k"]
    stream_format_args = ["-f", "adts"]
    try:
        volume_step = int(request.GET.get("volume", "20"))
    except (TypeError, ValueError):
        return HttpResponseBadRequest("Invalid playback volume.")
    if volume_step < 0 or volume_step > 20:
        return HttpResponseBadRequest("Playback volume must be 0 to 20.")
    try:
        speed_numerator = int(request.GET.get("speedNumerator", "1"))
        speed_denominator = int(request.GET.get("speedDenominator", "1"))
    except (TypeError, ValueError):
        return HttpResponseBadRequest("Invalid source playback speed.")
    if not 1 <= speed_numerator <= 128 or not 1 <= speed_denominator <= 128:
        return HttpResponseBadRequest("Source playback speed is outside the supported range.")
    speed_ticks = speed_numerator * 64
    if speed_ticks % speed_denominator or not 32 <= speed_ticks // speed_denominator <= 128:
        return HttpResponseBadRequest("Source playback speed must use 1/64 steps from 1/2 to 2.")

    decoder = None
    encoder = None
    materialized_track = tempfile.TemporaryDirectory(prefix="spcboy-track-")
    audio_path = Path(materialized_track.name) / f"selected{member_suffix}"
    try:
        track_index = int(track["trackIndex"])
        start_ms = int(request.GET.get("start", "0"))
        if member_suffix == ".spc":
            try:
                fade_seconds = int(request.GET.get("spcFade", str(DEFAULT_SPC_FADE_MS // 1000)))
            except (TypeError, ValueError):
                materialized_track.cleanup()
                return HttpResponseBadRequest("Invalid SPC fade duration.")
            if fade_seconds < 0 or fade_seconds > 30:
                materialized_track.cleanup()
                return HttpResponseBadRequest("SPC fade must be 0 to 30 whole seconds.")
            fade_ms = fade_seconds * 1000
            play_ms = DEFAULT_SPC_TOTAL_MS - fade_ms
        else:
            play_ms = int(track["playMilliseconds"])
            fade_ms = int(track.get("fadeMilliseconds", 0))
    except (KeyError, TypeError, ValueError):
        materialized_track.cleanup()
        return HttpResponse(status=404)
    if (
        track_index < 0
        or play_ms <= 0
        or play_ms > 24 * 60 * 60 * 1000
        or fade_ms < 0
        or fade_ms > 120_000
        or start_ms < 0
    ):
        materialized_track.cleanup()
        return HttpResponseBadRequest("Invalid playback position.")

    # Match SB2: the playback fade applies to every format, not only SPC.
    try:
        requested_fade = int(request.GET.get("fade", request.GET.get("spcFade", "5")))
        if not 0 <= requested_fade <= 30:
            raise ValueError
    except (TypeError, ValueError):
        materialized_track.cleanup()
        return HttpResponseBadRequest("Fade must be 0 to 30 whole seconds.")
    fade_ms = requested_fade * 1000
    if member_suffix == ".spc":
        play_ms = DEFAULT_SPC_TOTAL_MS - fade_ms

    long_play_enabled = False
    if "longPlay" in request.GET:
        long_play_value = request.GET.get("longPlay", "")
        try:
            long_play_seconds = int(long_play_value)
        except (TypeError, ValueError):
            materialized_track.cleanup()
            return HttpResponseBadRequest("Invalid long-play duration.")
        try:
            play_ms, fade_ms = long_play_timing(
                long_play_seconds, fade_ms, start_ms,
                max(1, int((page_session_limit_seconds - page_age_seconds) * 1000)),
                speed_numerator, speed_denominator,
            )
        except ValueError as error:
            materialized_track.cleanup()
            return HttpResponseBadRequest(str(error))
        long_play_enabled = True
    if start_ms >= play_ms + fade_ms:
        materialized_track.cleanup()
        return HttpResponseBadRequest("Invalid playback position.")

    try:
        prepare_with_vgmboy(archive_path, member_name, audio_path)
        if time.time() - page_loaded_at >= page_session_limit_seconds:
            materialized_track.cleanup()
            return HttpResponseGone("Playback session expired. Reload the page to continue.")
        decoder = subprocess.Popen(
            [
                str(settings.SPCBOY_STREAMER),
                str(audio_path),
                str(track_index),
                str(play_ms),
                str(fade_ms),
                str(start_ms),
                "1" if long_play_enabled else "0",
                str(speed_numerator),
                str(speed_denominator),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )
        encoder = subprocess.Popen(
            [
                settings.SPCBOY_FFMPEG,
                "-hide_banner",
                "-loglevel",
                "error",
                "-nostdin",
                "-f",
                "s16le",
                "-ar",
                "44100",
                "-ac",
                "2",
                "-i",
                "pipe:0",
                "-af",
                f"volume={volume_step / 20:.2f}",
                "-map",
                "0:a:0",
                *stream_encoding_args,
                "-ar",
                "44100",
                "-ac",
                "2",
                "-flush_packets",
                "1",
                *stream_format_args,
                "pipe:1",
            ],
            stdin=decoder.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )
        if decoder.stdout is not None:
            decoder.stdout.close()
    except (OSError, RuntimeError, subprocess.TimeoutExpired):
        logger.exception("Could not start SPCBOY playback pipeline.")
        for process in (encoder, decoder):
            if process is not None:
                if process.stdout is not None:
                    process.stdout.close()
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
        materialized_track.cleanup()
        return HttpResponse(status=503)

    history_saved = False
    quota_exhausted = False
    playback_session_expired = False
    priming_frame = AACADTSPrimingFrameStripper()

    def stream_audio():
        nonlocal history_saved, quota_exhausted, playback_session_expired
        try:
            if encoder.stdout is not None:
                while time.time() - page_loaded_at < page_session_limit_seconds:
                    time_remaining = page_session_limit_seconds - (time.time() - page_loaded_at)
                    readable, _, _ = select.select([encoder.stdout], [], [], min(.5, max(0, time_remaining)))
                    if not readable:
                        continue
                    chunk = encoder.stdout.read(4096)
                    if not chunk or time.time() - page_loaded_at >= page_session_limit_seconds:
                        playback_session_expired = time.time() - page_loaded_at >= page_session_limit_seconds
                        break
                    try:
                        chunk = priming_frame.push(chunk)
                    except ValueError:
                        logger.exception("FFmpeg did not produce the expected SPCBOY AAC stream.")
                        return
                    if not chunk:
                        continue
                    if not history_saved:
                        try:
                            _record_spcboy_playback(request.user.pk, playback_id, track_id, track)
                        except DatabaseError:
                            # History persistence must not interrupt a live audio stream.
                            logger.exception("Could not save an SPCBOY playback history event.")
                        history_saved = True
                    try:
                        allowed = claim_audio_stream_bytes(request.user.pk, len(chunk))
                    except DatabaseError:
                        logger.exception("Could not account for SPCBOY audio bytes; stopping this stream.")
                        quota_exhausted = True
                        break
                    if allowed <= 0:
                        quota_exhausted = True
                        break
                    yield chunk[:allowed]
                    if allowed < len(chunk):
                        quota_exhausted = True
                        break
                if time.time() - page_loaded_at >= page_session_limit_seconds:
                    playback_session_expired = True
            if not quota_exhausted and not playback_session_expired:
                encoder.wait()
                decoder.wait()
        finally:
            if encoder.stdout is not None:
                encoder.stdout.close()
            for process in (encoder, decoder):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            materialized_track.cleanup()

    response = StreamingHttpResponse(stream_audio(), content_type="audio/aac")
    response["Cache-Control"] = "private, no-store"
    response["X-Accel-Buffering"] = "no"
    response["X-Audio-Duration"] = str((play_ms + fade_ms) / 1000)
    response["X-Content-Type-Options"] = "nosniff"
    # This is a live generated stream, not a stored byte-addressable media file.
    response["Accept-Ranges"] = "none"
    return response


@login_required
@never_cache
@require_GET
def spcboy_stream_quota(request):
    period = _month_start()
    used = audio_stream_usage(request.user.pk, period)
    remaining = max(0, MONTHLY_AUDIO_STREAM_LIMIT_BYTES - used)
    return JsonResponse({
        "period": period.isoformat(),
        "used": used,
        "limit": MONTHLY_AUDIO_STREAM_LIMIT_BYTES,
        "remaining": remaining,
    }, headers={"Cache-Control": "private, no-store"})


@login_required
def server_status(request):
    denied = _owner_required(request)
    if denied:
        return denied
    return redirect("usage")


@login_required
def site_log(request):
    denied = _owner_required(request)
    if denied:
        return denied
    active_logins, active_session_digests = _active_account_sessions(request)
    rows = [row for row in _account_rows(active_logins) if row.device_count]
    history = Paginator(LoginEvent.objects.all(), 50).get_page(request.GET.get("log_page"))
    _decorate_history(history, active_session_digests)
    event_usernames = {event.username for event in history.object_list if event.username}
    current_handles = dict(
        MemberProfile.objects.filter(user__username__in=event_usernames)
        .values_list("user__username", "display_name")
    )
    for event in history.object_list:
        event.display_username = current_handles.get(event.username, event.username)
    recent_events = LoginEvent.objects.filter(occurred_at__gte=timezone.now() - timedelta(hours=24))
    return render(request, "accounts/site_log.html", {
        "active_accounts": rows,
        "active_device_count": len(active_logins),
        "history": history,
        "successful_signins_24h": recent_events.filter(event_type=LoginEvent.LOGIN_SUCCESS).count(),
        "failed_signins_24h": recent_events.filter(event_type=LoginEvent.LOGIN_FAILED).count(),
    })


@login_required
def usage(request):
    denied = _owner_required(request)
    if denied:
        return denied
    current_period = timezone.now().astimezone(datetime_timezone.utc).date().replace(day=1)
    period_value = request.GET.get("month", "")
    try:
        selected_period = datetime.strptime(period_value, "%Y-%m").date().replace(day=1)
    except ValueError:
        selected_period = current_period

    available_periods = list(
        MonthlyUsage.objects.values_list("period", flat=True).distinct().order_by("-period")[:24]
    )
    if current_period not in available_periods:
        available_periods.insert(0, current_period)
    if selected_period not in available_periods:
        selected_period = current_period

    usage_by_user = {
        usage.user_id: usage
        for usage in MonthlyUsage.objects.filter(period=selected_period)
    }
    users = list(User.objects.order_by("username"))
    passkey_accounts = {
        account.user_id: account
        for account in PasskeyAccount.objects.filter(user_id__in=[user.pk for user in users])
    }
    rows = []
    for user in users:
        usage = usage_by_user.get(user.pk)
        site_bytes = usage.site_bytes if usage else 0
        media_bytes = usage.media_bytes if usage else 0
        audio_bytes = usage.audio_bytes if usage else 0
        passkey_account = passkey_accounts.get(user.pk)
        rows.append({
            "username": _member_profile(user).display_name,
            "role_label": "Owner" if user.is_superuser else "Staff" if user.is_staff else "Member",
            "is_active": user.is_active,
            "site_bytes": _bytes_label(site_bytes),
            "media_bytes": _bytes_label(media_bytes),
            "audio_quota": f"{_bytes_label(audio_bytes)} / {_bytes_label(MONTHLY_AUDIO_STREAM_LIMIT_BYTES)}",
            "total_bytes": _bytes_label(site_bytes + media_bytes),
        })
    site_total = sum(usage.site_bytes for usage in usage_by_user.values())
    media_total = sum(usage.media_bytes for usage in usage_by_user.values())
    context = {
        "rows": rows,
        "periods": [{"value": _month_label(period), "label": _month_label(period)} for period in available_periods],
        "selected_period": _month_label(selected_period),
        "is_current_period": selected_period == current_period,
        "site_total": _bytes_label(site_total),
        "media_total": _bytes_label(media_total),
        "total": _bytes_label(site_total + media_total),
        "is_owner": request.user.is_superuser,
    }
    if request.user.is_superuser:
        context["bandwidth"] = _bandwidth_stats()
        context["server"] = _server_stats()
        context["backup"] = _backup_status()
    return render(request, "accounts/usage.html", context)


@require_POST
def logout_view(request):
    if request.user.is_authenticated:
        mark_session_signed_out(request.session.session_key)
    auth_logout(request)
    return redirect("login")


@login_required
@never_cache
def passkey_settings(request):
    return redirect(f"{reverse('member_profile')}?tab=security")


@login_required
@never_cache
@require_http_methods(["GET", "POST"])
def accounts(request):
    denied = _owner_required(request)
    if denied:
        return denied
    site_settings, _ = SiteSettings.objects.get_or_create(pk=1)
    site_form = SiteSettingsForm(request.POST if request.method == "POST" else None, instance=site_settings)
    if request.method == "POST" and site_form.is_valid():
        site_form.save()
        messages.success(request, "Site settings saved. New playback sessions use these settings.")
        return redirect("accounts")
    active_logins, _ = _active_account_sessions(request)
    context = {
        "site_settings_form": site_form,
        "account_rows": _account_rows(active_logins),
        "is_owner": request.user.is_superuser,
    }
    if request.user.is_superuser:
        invitations = list(Invitation.objects.filter(
            is_recovery=False,
            used_at__isnull=True,
            revoked_at__isnull=True,
            expires_at__gt=timezone.now(),
        ).order_by("-created_at"))
        for invitation in invitations:
            invitation.visible_code = _decrypt_invitation_code(invitation)
        context["invitations"] = invitations
        context["unrecoverable_invitation_count"] = sum(
            invitation.visible_code is None for invitation in invitations
        )
    return render(request, "accounts/accounts.html", context)


@login_required
@require_POST
def create_invite(request):
    denied = _owner_required(request)
    if denied:
        return denied
    invitation, code = _create_invitation(
        creator=request.user.username,
    )
    return _show_invitation_code(request, invitation, code)


@login_required
@require_POST
def create_passkey_recovery_invite(request, user_id):
    denied = _owner_required(request)
    if denied:
        return denied
    member = get_object_or_404(User, pk=user_id, is_staff=False, is_superuser=False)
    if not member.is_active:
        messages.error(request, "Reactivate this account before issuing a passkey recovery invitation.")
        return redirect("accounts")
    Invitation.objects.filter(
        username__iexact=member.username,
        is_recovery=True,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=timezone.now())
    invitation, code = _create_invitation(
        username=member.username,
        creator=request.user.username,
        is_recovery=True,
    )
    return _show_invitation_code(request, invitation, code)


@login_required
@require_GET
def invite_created(request):
    denied = _owner_required(request)
    if denied:
        return denied
    result = request.session.pop("created_invitation_result", None)
    if (
        not isinstance(result, dict)
        or not result.get("selector")
        or not result.get("code")
    ):
        return redirect("accounts")
    if result.get("expires", 0) < time.time():
        messages.error(request, "The code display expired. Cancel that invite and create a fresh code if needed.")
        return redirect("accounts")
    invitation = get_object_or_404(Invitation, selector=result["selector"])
    if not invitation.is_open:
        messages.error(request, "That invitation is no longer open. Create a fresh code if needed.")
        return redirect("accounts")
    return render(request, "accounts/invite_created.html", {
        "member_invite": not invitation.is_recovery,
        "join_url": request.build_absolute_uri(reverse("join_code")),
        "invitation_url": _invitation_url(request, invitation),
        "code": result["code"],
        "username": invitation.username if invitation.is_recovery else "",
        "expires_at": invitation.expires_at,
    })


@login_required
@require_POST
def revoke_invite(request, invite_id):
    denied = _owner_required(request)
    if denied:
        return denied
    invitation = get_object_or_404(Invitation, selector=invite_id, used_at__isnull=True, revoked_at__isnull=True)
    invitation.revoked_at = timezone.now()
    invitation.save(update_fields=["revoked_at"])
    messages.success(request, "Invitation canceled.")
    destination = request.POST.get("return_to")
    return redirect("dashboard" if destination == "dashboard" else "accounts")


@login_required
@require_POST
def toggle_user(request, user_id):
    denied = _owner_required(request)
    if denied:
        return denied
    member = get_object_or_404(User, pk=user_id, is_staff=False, is_superuser=False)
    if member.pk == request.user.pk:
        raise PermissionDenied
    member.is_active = not member.is_active
    member.save(update_fields=["is_active"])
    state = "reactivated" if member.is_active else "suspended"
    messages.success(request, f"Account {member.username} {state}.")
    return redirect("accounts")


@login_required
@require_http_methods(["GET", "POST"])
def delete_user(request, user_id):
    denied = _owner_required(request)
    if denied:
        return denied
    member = get_object_or_404(User, pk=user_id, is_staff=False, is_superuser=False)
    account = PasskeyAccount.objects.filter(user=member, username_set=False).first()
    member_label = "Pending join" if account else member.username

    if request.method == "GET":
        return render(request, "accounts/delete_user.html", {"member": member, "member_label": member_label})

    now = timezone.now()
    with transaction.atomic():
        member = get_object_or_404(
            User.objects.select_for_update(),
            pk=user_id,
            is_staff=False,
            is_superuser=False,
        )

        session_keys = []
        for session in Session.objects.filter(expire_date__gt=now).iterator():
            try:
                session_user_id = int(session.get_decoded().get("_auth_user_id", ""))
            except (TypeError, ValueError, UnicodeDecodeError):
                continue
            if session_user_id == member.pk:
                session_keys.append(session.session_key)

        session_digests = [session_key_digest(key) for key in session_keys]
        session_digests = [digest for digest in session_digests if digest]
        if session_keys:
            Session.objects.filter(session_key__in=session_keys).delete()
        if session_digests:
            LoginEvent.objects.filter(
                event_type=LoginEvent.LOGIN_SUCCESS,
                session_key_digest__in=session_digests,
                ended_at__isnull=True,
            ).update(
                ended_at=now,
                last_seen_at=now,
                end_reason=LoginEvent.END_SESSION_ENDED,
            )

        Invitation.objects.filter(
            username__iexact=member.username,
            used_at__isnull=True,
            revoked_at__isnull=True,
            expires_at__gt=now,
        ).update(revoked_at=now)
        username = "Pending join" if PasskeyAccount.objects.filter(user=member, username_set=False).exists() else member.username
        member.delete()

    messages.success(request, f"Account {username} was permanently deleted. Site Log history was retained.")
    return redirect("accounts")


def _invite_page(request, invitation, *, form=None, error=None, status=200):
    return render(request, "accounts/enroll.html", {
        "invitation": invitation,
        "form": form or EnrollmentForm(),
        "error": error,
    }, status=status)


def _pending_username_user(request, invitation):
    if request.session.get("pending_username_invitation_id") != invitation.pk:
        return None
    if request.session.get("pending_username_expires", 0) < time.time():
        return None
    user_id = request.session.get("pending_username_user_id")
    user = User.objects.filter(pk=user_id, is_active=True).first()
    account = PasskeyAccount.objects.filter(user=user).first() if user else None
    if user is None or account is None or not user.passkeys.exists():
        return None
    return user


def _pending_passkey_user(request, invitation):
    if request.session.get("pending_passkey_invitation_id") != invitation.pk:
        return None
    if request.session.get("pending_passkey_expires", 0) < time.time():
        return None
    if bool(request.session.get("pending_passkey_recovery")) != invitation.is_recovery:
        return None
    user_id = request.session.get("pending_passkey_user_id")
    user = User.objects.filter(pk=user_id, is_active=True).first()
    if user is None:
        return None
    if not invitation.is_recovery:
        account = PasskeyAccount.objects.filter(user=user).first()
        if account is None or user.passkeys.exists():
            return None
    return user


def _passkey_registration_user(request):
    if request.user.is_authenticated:
        return request.user
    expires = request.session.get("pending_passkey_expires", 0)
    user_id = request.session.get("pending_passkey_user_id")
    if expires < time.time() or not user_id:
        return None
    return User.objects.filter(pk=user_id, is_active=True).first()


def _passkey_json(request):
    if len(request.body) > 65_536:
        return None
    try:
        payload = json.loads(request.body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def _passkey_failure(request, username=""):
    LoginEvent.objects.create(
        event_type=LoginEvent.LOGIN_FAILED,
        username=username[:64],
        ip_address=request_ip_address(request),
        user_agent=request_user_agent(request),
    )


@never_cache
@require_POST
def passkey_registration_options(request):
    user = _passkey_registration_user(request)
    if user is None:
        return JsonResponse({"error": "Sign in or finish account setup before adding a passkey."}, status=403)
    options, challenge = registration_options(user)
    request.session["passkey_registration_challenge"] = {
        "challenge": challenge,
        "user_id": user.pk,
        "expires": time.time() + 120,
    }
    return JsonResponse(options)


@never_cache
@require_POST
def passkey_registration_verify(request):
    challenge = request.session.pop("passkey_registration_challenge", None)
    request.session.modified = True
    user = _passkey_registration_user(request)
    if (
        user is None
        or not challenge
        or challenge.get("user_id") != user.pk
        or challenge.get("expires", 0) < time.time()
    ):
        return JsonResponse({"error": "Passkey setup expired. Start again."}, status=400)
    payload = _passkey_json(request)
    if not payload or not isinstance(payload.get("response"), dict):
        return JsonResponse({"error": "The passkey response was incomplete."}, status=400)
    try:
        verified = verify_registration(payload, user, challenge["challenge"])
    except Exception:
        return JsonResponse({"error": "This passkey could not be verified. Try again."}, status=400)
    pending_enrollment = not request.user.is_authenticated
    pending_recovery = pending_enrollment and request.session.get("pending_passkey_recovery", False)
    existing_credential = PasskeyCredential.objects.filter(credential_id=verified["credential_id"]).first()
    if existing_credential and not (pending_recovery and existing_credential.user_id == user.pk):
        return JsonResponse({"error": "That passkey is already registered."}, status=409)

    name = str(payload.get("name", "")).strip()[:80] or "Passkey"
    transports = payload.get("response", {}).get("transports", [])
    allowed_transports = {"ble", "hybrid", "internal", "nfc", "usb"}
    if not isinstance(transports, list):
        transports = []
    transports = [value for value in transports if isinstance(value, str) and value in allowed_transports]
    try:
        with transaction.atomic():
            if pending_recovery:
                user.passkeys.all().delete()
            PasskeyCredential.objects.create(
                user=user,
                credential_id=verified["credential_id"],
                public_key=verified["public_key"],
                sign_count=verified["sign_count"],
                transports=transports,
                name=name,
                last_used_at=timezone.now() if pending_enrollment else None,
            )
    except IntegrityError:
        return JsonResponse({"error": "That passkey is already registered."}, status=409)

    if pending_enrollment:
        request.session.pop("pending_passkey_user_id", None)
        request.session.pop("pending_passkey_expires", None)
        request.session.pop("pending_passkey_recovery", None)
        PasskeyAccount.objects.filter(user=user, username_set=False).update(username_set=True)
        if pending_recovery:
            request.session.pop("pending_passkey_invitation_id", None)
            login(request, user, backend=settings.AUTHENTICATION_BACKENDS[0])
            return JsonResponse({"success": True, "name": name, "redirect_url": reverse("spcboy")})
        login(request, user, backend=settings.AUTHENTICATION_BACKENDS[0])
        return JsonResponse({"success": True, "name": name, "redirect_url": reverse("spcboy")})
    return JsonResponse({"success": True, "name": name})


@never_cache
@require_POST
def passkey_login_options(request):
    if request.user.is_authenticated:
        return JsonResponse({"error": "You are already signed in."}, status=400)
    options, challenge = authentication_options()
    request.session["passkey_login_challenge"] = {
        "challenge": challenge,
        "expires": time.time() + 120,
    }
    return JsonResponse(options)


@never_cache
@require_POST
def passkey_login_verify(request):
    challenge = request.session.pop("passkey_login_challenge", None)
    request.session.modified = True
    payload = _passkey_json(request)
    if (
        not challenge
        or challenge.get("expires", 0) < time.time()
        or not payload
        or not isinstance(payload.get("response"), dict)
    ):
        return JsonResponse({"error": "Passkey sign-in expired. Try again."}, status=400)
    credential_id = payload.get("rawId")
    credential = PasskeyCredential.objects.select_related("user").filter(credential_id=credential_id).first()
    if credential is None or not credential.user.is_active:
        _passkey_failure(request)
        return JsonResponse({"error": "That passkey was not accepted."}, status=400)
    account = PasskeyAccount.objects.filter(user=credential.user).first()
    try:
        if account is None:
            raise ValueError("The passkey account is missing.")
        verified = verify_authentication(payload, credential, account, challenge["challenge"])
        if credential.sign_count and verified.new_sign_count and verified.new_sign_count <= credential.sign_count:
            raise ValueError("The authenticator counter did not advance.")
    except Exception:
        _passkey_failure(request, credential.user.get_username())
        return JsonResponse({"error": "That passkey was not accepted."}, status=400)

    credential.sign_count = max(credential.sign_count, verified.new_sign_count)
    credential.last_used_at = timezone.now()
    credential.save(update_fields=["sign_count", "last_used_at"])
    if not account.username_set:
        account.username_set = True
        account.save(update_fields=["username_set"])
    login(request, credential.user, backend=settings.AUTHENTICATION_BACKENDS[0])
    next_url = payload.get("next")
    if not isinstance(next_url, str) or not url_has_allowed_host_and_scheme(
        next_url,
        allowed_hosts={request.get_host()},
        require_https=request.is_secure(),
    ):
        next_url = reverse("spcboy")
    return JsonResponse({"success": True, "redirect_url": next_url})


@login_required
@never_cache
@require_POST
def remove_passkey(request, credential_id):
    credential = get_object_or_404(PasskeyCredential, pk=credential_id, user=request.user)
    if request.user.passkeys.count() <= 1:
        messages.error(request, "Keep at least one passkey on the account. Add another before removing this one.")
        return redirect(f"{reverse('member_profile')}?tab=security")
    credential.delete()
    messages.success(request, "Passkey removed.")
    return redirect(f"{reverse('member_profile')}?tab=security")


def _bad_invitation_code(invitation):
    Invitation.objects.filter(pk=invitation.pk).update(failed_attempts=F("failed_attempts") + 1)
    invitation.refresh_from_db()
    if invitation.failed_attempts >= MAX_PASSKEY_ATTEMPTS:
        invitation.revoked_at = timezone.now()
        invitation.save(update_fields=["revoked_at"])


def _join_code_page(request, *, form=None, error=None, status=200):
    return render(request, "accounts/join_code.html", {
        "form": form or EnrollmentForm(),
        "error": error,
    }, status=status)


def _join_code_throttled_response(request, blocked_until):
    response = _join_code_page(
        request,
        error="Too many invalid invite codes. Access from this connection is paused for 24 hours.",
        status=429,
    )
    response["Retry-After"] = str(max(1, int((blocked_until - timezone.now()).total_seconds())))
    return response


def _pending_invitation_page(request, invitation):
    pending_username_user = _pending_username_user(request, invitation)
    if pending_username_user:
        account = PasskeyAccount.objects.filter(user=pending_username_user).first()
        if account and not account.username_set:
            account.username_set = True
            account.save(update_fields=["username_set"])
        for key in ("pending_username_user_id", "pending_username_invitation_id", "pending_username_expires"):
            request.session.pop(key, None)
        login(request, pending_username_user, backend=settings.AUTHENTICATION_BACKENDS[0])
        return redirect("spcboy")
    pending_user = _pending_passkey_user(request, invitation)
    if pending_user:
        return render(request, "accounts/passkey_enroll.html", {
            "username": pending_user.get_username(),
            "is_recovery": invitation.is_recovery,
        })
    return None


def _claim_invitation(request, invitation, provided_code, *, code_form=None):
    if invitation.failed_attempts >= MAX_PASSKEY_ATTEMPTS:
        return HttpResponseGone("This one-time invitation is no longer available.")
    if not invitation.is_open:
        return _pending_invitation_page(request, invitation) or HttpResponseGone(
            "This one-time invitation is no longer available."
        )
    if invitation.is_recovery:
        target = User.objects.filter(username=invitation.username, is_active=True).first()
        if target is None:
            return HttpResponseGone("This one-time invitation is no longer available.")
    elif User.objects.filter(username__iexact=invitation.username).exists():
        return HttpResponseGone("This one-time invitation is no longer available.")

    try:
        with transaction.atomic():
            locked = Invitation.objects.select_for_update().get(pk=invitation.pk)
            if not locked.is_open or locked.failed_attempts >= MAX_PASSKEY_ATTEMPTS:
                return HttpResponseGone("This one-time invitation is no longer available.")
            if not hmac.compare_digest(_digest(provided_code), locked.invitation_code_digest):
                _bad_invitation_code(locked)
                if not locked.is_recovery:
                    blocked_until = _record_invite_failure(request)
                    if blocked_until and blocked_until > timezone.now():
                        return _join_code_throttled_response(request, blocked_until)
                error = "The one-time invitation code is invalid or expired."
                if locked.is_recovery:
                    return _invite_page(request, locked, form=code_form, error=error, status=400)
                return _join_code_page(request, form=code_form, error=error, status=400)

            if locked.is_recovery:
                user = User.objects.get(username=locked.username, is_active=True)
            else:
                if locked.username_assigned and User.objects.filter(username__iexact=locked.username).exists():
                    return HttpResponseGone("This one-time invitation is no longer available.")
                user = User(
                    username=locked.username,
                    is_staff=locked.is_admin,
                    is_superuser=locked.is_admin,
                )

            user.set_unusable_password()
            if locked.is_recovery:
                user.save(update_fields=["password"])
            else:
                user.save(force_insert=True)
                PasskeyAccount.objects.create(user=user, username_set=True)

            locked.used_at = timezone.now()
            locked.invitation_code_digest = _digest(secrets.token_urlsafe(32))
            locked.save(update_fields=["used_at", "invitation_code_digest"])
    except (IntegrityError, User.DoesNotExist):
        return HttpResponseGone("This one-time invitation is no longer available.")

    if request.user.is_authenticated:
        mark_session_signed_out(request.session.session_key)
        auth_logout(request)
    request.session["pending_passkey_user_id"] = user.pk
    request.session["pending_passkey_expires"] = time.time() + PENDING_ENROLLMENT_LIFETIME.total_seconds()
    request.session["pending_passkey_recovery"] = locked.is_recovery
    request.session["pending_passkey_invitation_id"] = locked.pk
    if not locked.is_recovery:
        InviteCodeAttempt.objects.filter(ip_digest=_invite_attempt_digest(request)).delete()
    return render(request, "accounts/passkey_enroll.html", {
        "username": user.get_username(),
        "is_recovery": locked.is_recovery,
    })


@never_cache
@require_http_methods(["GET", "POST"])
def enroll_by_code(request):
    if request.method == "GET":
        pending_id = (
            request.session.get("pending_username_invitation_id")
            or request.session.get("pending_passkey_invitation_id")
        )
        invitation = Invitation.objects.filter(pk=pending_id, is_recovery=False, used_at__isnull=False).first()
        if invitation is not None:
            pending_page = _pending_invitation_page(request, invitation)
            if pending_page is not None:
                return pending_page
        return _join_code_page(request)

    blocked_until = _invite_blocked_until(request)
    if blocked_until:
        return _join_code_throttled_response(request, blocked_until)

    form = EnrollmentForm(request.POST)
    if not form.is_valid():
        blocked_until = _record_invite_failure(request)
        if blocked_until and blocked_until > timezone.now():
            return _join_code_throttled_response(request, blocked_until)
        return _join_code_page(request, form=form, error="The one-time invitation code is invalid or expired.", status=400)
    code = form.cleaned_data["invitation_code"]
    code_alphabet = set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    if len(code) == 8 and all(character in code_alphabet for character in code):
        invitation = Invitation.objects.filter(
            invitation_code_digest=_digest(code),
            is_recovery=False,
        ).first()
        if invitation is not None:
            return _claim_invitation(request, invitation, code, code_form=form)
    selector_part, separator, secret_code = code.partition("-")
    if (
        not separator
        or len(selector_part) != 32
        or len(secret_code) != 16
        or any(character not in "0123456789ABCDEF" for character in selector_part)
        or any(character not in code_alphabet for character in secret_code)
    ):
        invitation = None
    else:
        try:
            invitation = Invitation.objects.filter(
                selector=uuid.UUID(hex=selector_part),
                is_recovery=False,
            ).first()
        except ValueError:
            invitation = None
    if invitation is not None:
        return _claim_invitation(request, invitation, secret_code, code_form=form)
    blocked_until = _record_invite_failure(request)
    if blocked_until and blocked_until > timezone.now():
        return _join_code_throttled_response(request, blocked_until)
    return _join_code_page(request, form=form, error="The one-time invitation code is invalid or expired.", status=400)


@never_cache
@require_http_methods(["GET", "POST"])
def enroll(request, invite_id):
    invitation = get_object_or_404(Invitation, selector=invite_id, is_recovery=True)
    if request.method == "GET":
        if not invitation.is_open:
            return _pending_invitation_page(request, invitation) or HttpResponseGone(
                "This one-time invitation is no longer available."
            )
        return _invite_page(request, invitation)
    form = EnrollmentForm(request.POST)
    if not form.is_valid():
        return _invite_page(request, invitation, form=form)
    return _claim_invitation(
        request,
        invitation,
        form.cleaned_data["invitation_code"],
        code_form=form,
    )


def robots(request):
    response = HttpResponse("User-agent: *\nDisallow: /\n", content_type="text/plain; charset=utf-8")
    response["X-Robots-Tag"] = "noindex, nofollow, noarchive"
    return response
