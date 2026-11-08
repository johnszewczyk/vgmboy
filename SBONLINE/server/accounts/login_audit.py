import hashlib
import ipaddress
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.sessions.models import Session
from django.db.models import Q
from django.utils import timezone
from django.utils.crypto import constant_time_compare

from .models import LoginEvent


User = get_user_model()


def session_key_digest(session_key):
    if not session_key:
        return None
    return hashlib.sha256(session_key.encode("utf-8")).hexdigest()


def request_ip_address(request):
    # Gunicorn is loopback-only, and the Nginx virtual host overwrites this
    # header with $remote_addr before proxying to the application.
    candidate = request.META.get("HTTP_X_REAL_IP", "").strip()
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return None


def request_user_agent(request):
    return request.META.get("HTTP_USER_AGENT", "")[:512]


def touch_login_session(request):
    if not request.user.is_authenticated:
        return
    digest = session_key_digest(request.session.session_key)
    if not digest:
        return
    now = timezone.now()
    LoginEvent.objects.filter(
        event_type=LoginEvent.LOGIN_SUCCESS,
        session_key_digest=digest,
        ended_at__isnull=True,
    ).filter(
        Q(last_seen_at__isnull=True) | Q(last_seen_at__lt=now - timedelta(seconds=60))
    ).update(last_seen_at=now)


def online_user_count():
    now = timezone.now()
    online_usernames = User.objects.filter(
        is_active=True,
        passkeys__isnull=False,
    ).values("username")
    return LoginEvent.objects.filter(
        event_type=LoginEvent.LOGIN_SUCCESS,
        ended_at__isnull=True,
        last_seen_at__gte=now - timedelta(minutes=5),
        username__in=online_usernames,
    ).values("username").distinct().count()


def mark_session_signed_out(session_key):
    digest = session_key_digest(session_key)
    if not digest:
        return
    now = timezone.now()
    LoginEvent.objects.filter(
        event_type=LoginEvent.LOGIN_SUCCESS,
        session_key_digest=digest,
        ended_at__isnull=True,
    ).update(ended_at=now, last_seen_at=now, end_reason=LoginEvent.END_SIGNED_OUT)


def _session_auth_hash_is_valid(user, session_data):
    session_hash = session_data.get("_auth_user_hash")
    if not session_hash:
        return False
    expected_hashes = [user.get_session_auth_hash()]
    expected_hashes.extend(user.get_session_auth_fallback_hash())
    return any(constant_time_compare(session_hash, expected) for expected in expected_hashes)


def active_login_sessions(current_session_key=None):
    now = timezone.now()
    decoded_sessions = []
    user_ids = set()
    for session in Session.objects.filter(expire_date__gt=now).iterator():
        try:
            data = session.get_decoded()
            user_id = int(data.get("_auth_user_id", ""))
        except (TypeError, ValueError, UnicodeDecodeError):
            continue
        decoded_sessions.append((session, data, user_id))
        user_ids.add(user_id)

    users = User.objects.in_bulk(user_ids)
    valid_sessions = []
    digests = set()
    for session, data, user_id in decoded_sessions:
        user = users.get(user_id)
        if (
            user is None
            or not user.is_active
            or data.get("_auth_user_backend") not in settings.AUTHENTICATION_BACKENDS
            or not _session_auth_hash_is_valid(user, data)
        ):
            continue
        digest = session_key_digest(session.session_key)
        digests.add(digest)
        valid_sessions.append((digest, user))

    records = {
        record.session_key_digest: record
        for record in LoginEvent.objects.filter(
            event_type=LoginEvent.LOGIN_SUCCESS,
            session_key_digest__in=digests,
            ended_at__isnull=True,
        ).order_by("occurred_at", "pk")
    } if digests else {}
    current_digest = session_key_digest(current_session_key)
    active = []
    for digest, user in valid_sessions:
        record = records.get(digest)
        active.append({
            "user_id": user.pk,
            "username": user.get_username(),
            "session_id": digest,
            "ip_address": record.ip_address if record else None,
            "user_agent": record.user_agent if record else "",
            "login_at": record.occurred_at if record else None,
            "last_seen_at": record.last_seen_at if record else None,
            "is_current": digest == current_digest,
            "pre_audit": record is None,
        })
    active.sort(key=lambda item: (not item["is_current"], item["login_at"] is None, item["login_at"] or now))
    return active, digests


def close_missing_sessions(active_session_digests):
    now = timezone.now()
    open_events = LoginEvent.objects.filter(
        event_type=LoginEvent.LOGIN_SUCCESS,
        ended_at__isnull=True,
    )
    if active_session_digests:
        open_events.exclude(session_key_digest__in=active_session_digests).update(
            ended_at=now,
            end_reason=LoginEvent.END_SESSION_ENDED,
        )
    else:
        open_events.update(ended_at=now, end_reason=LoginEvent.END_SESSION_ENDED)
