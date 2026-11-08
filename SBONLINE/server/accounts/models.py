import uuid
import secrets

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.functions import Lower
from django.utils import timezone

THEME_PREFERENCES = [
    ("system", "Use device setting"),
    ("dark", "Dark"),
    ("light", "Light"),
]

PLAYER_SESSION_LIMIT_MINUTES_MIN = 1
PLAYER_SESSION_LIMIT_MINUTES_MAX = 1_440


def new_passkey_user_handle():
    return secrets.token_urlsafe(32)


def member_avatar_upload_to(instance, filename):
    return f"avatars/{instance.user_id}/{uuid.uuid4().hex}.webp"


def community_image_upload_to(instance, filename):
    return f"posts/{instance.user_id}/{uuid.uuid4().hex}.webp"


class Invitation(models.Model):
    selector = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    username = models.CharField(max_length=64)
    invitation_code_digest = models.CharField(max_length=64)
    invitation_code_ciphertext = models.CharField(max_length=255, blank=True, default="")
    username_assigned = models.BooleanField(default=False)
    is_admin = models.BooleanField(default=False)
    is_recovery = models.BooleanField(default=False)
    created_by_username = models.CharField(max_length=150)
    created_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    failed_attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        label = self.username if self.username_assigned or self.is_recovery else "member"
        return f"Invitation for {label}"

    @property
    def is_open(self):
        return self.used_at is None and self.revoked_at is None and self.expires_at > timezone.now()

    @property
    def status(self):
        if self.used_at:
            return "Used"
        if self.revoked_at:
            return "Revoked"
        if self.expires_at <= timezone.now():
            return "Expired"
        return "Pending"


class LoginEvent(models.Model):
    LOGIN_SUCCESS = "success"
    LOGIN_FAILED = "failed"
    EVENT_CHOICES = [
        (LOGIN_SUCCESS, "Successful sign-in"),
        (LOGIN_FAILED, "Failed sign-in"),
    ]
    END_SIGNED_OUT = "signed_out"
    END_SESSION_ENDED = "ended"

    event_type = models.CharField(max_length=10, choices=EVENT_CHOICES, db_index=True)
    username = models.CharField(max_length=64, blank=True)
    occurred_at = models.DateTimeField(default=timezone.now, db_index=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=512, blank=True)
    # A digest lets the admin match an event to a live Django session without
    # putting a reusable session credential in the audit table.
    session_key_digest = models.CharField(max_length=64, null=True, blank=True, db_index=True)
    last_seen_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    end_reason = models.CharField(max_length=16, blank=True)

    class Meta:
        ordering = ["-occurred_at", "-pk"]

    def __str__(self):
        return f"{self.username or 'Unknown account'}: {self.event_type} at {self.occurred_at}"


class MonthlyUsage(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    period = models.DateField(help_text="First day of the UTC month")
    site_bytes = models.PositiveBigIntegerField(default=0)
    media_bytes = models.PositiveBigIntegerField(default=0)
    audio_bytes = models.PositiveBigIntegerField(default=0)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-period", "user__username"]
        constraints = [
            models.UniqueConstraint(fields=["user", "period"], name="unique_monthly_user_usage"),
        ]

    def __str__(self):
        return f"{self.user.get_username()} usage for {self.period:%Y-%m}"


class SPCBOYPlaybackHistory(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="spcboy_playback_history",
    )
    playback_id = models.UUIDField()
    track_id = models.CharField(max_length=64)
    title = models.CharField(max_length=300)
    game = models.CharField(max_length=300)
    console = models.CharField(max_length=100)
    played_at = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ["-played_at", "-pk"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "playback_id"],
                name="unique_spcboy_playback_event",
            ),
        ]

    def __str__(self):
        return f"{self.user.get_username()}: {self.title} at {self.played_at}"


class SPCBOYRecentHidden(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="spcboy_hidden_recents",
    )
    event = models.ForeignKey(
        SPCBOYPlaybackHistory,
        on_delete=models.CASCADE,
        related_name="hidden_from_recents",
    )
    hidden_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "event"],
                name="unique_spcboy_hidden_recent",
            ),
        ]

    def __str__(self):
        return f"{self.user.get_username()}: hide recent event {self.event_id}"


class SPCBOYNowPlaying(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="spcboy_now_playing",
    )
    playback_id = models.UUIDField()
    track_id = models.CharField(max_length=64)
    title = models.CharField(max_length=300)
    game = models.CharField(max_length=300)
    console = models.CharField(max_length=100)
    started_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ["-updated_at", "user_id"]


class MemberProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="member_profile")
    display_name = models.CharField(max_length=40)
    avatar = models.FileField(upload_to=member_avatar_upload_to, blank=True)
    theme_preference = models.CharField(max_length=8, choices=THEME_PREFERENCES, default="system")
    is_site_persona = models.BooleanField(default=False)
    spcboy_preferences = models.JSONField(default=dict, blank=True)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["display_name", "user_id"]
        constraints = [
            models.UniqueConstraint(
                Lower("display_name"),
                condition=~models.Q(display_name=""),
                name="unique_member_profile_display_name_ci",
            ),
        ]

    @property
    def initials(self):
        handle = self.display_name.strip() or self.user.get_username().strip()
        return handle[:1].upper() or "?"

    @property
    def avatar_url(self):
        if self.avatar:
            return self.avatar.url
        return ""

    def __str__(self):
        return self.display_name


class FavoriteTrack(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorite_tracks")
    track_id = models.CharField(max_length=64)
    added_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-added_at", "pk"]
        constraints = [
            models.UniqueConstraint(fields=["user", "track_id"], name="unique_user_favorite_track"),
        ]


class FavoriteAlbum(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorite_albums")
    album_id = models.CharField(max_length=32)
    added_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-added_at", "pk"]
        constraints = [
            models.UniqueConstraint(fields=["user", "album_id"], name="unique_user_favorite_album"),
        ]


class CommunityPost(models.Model):
    # Legacy Feed records remain stored; the user-facing Feed and posting flow are retired.
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="community_posts")
    text = models.CharField(max_length=2000, blank=True)
    image = models.FileField(upload_to=community_image_upload_to, blank=True)
    listening_track_id = models.CharField(max_length=64, blank=True)
    listening_title = models.CharField(max_length=300, blank=True)
    listening_game = models.CharField(max_length=300, blank=True)
    listening_console = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-created_at", "-pk"]


class MemberChatMessage(models.Model):
    # Legacy rows remain stored; the user-facing Chat feature and endpoints are retired.
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="member_chat_messages",
    )
    text = models.CharField(max_length=1000)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ["pk"]
        indexes = [models.Index(fields=["user", "created_at"], name="chat_user_time_idx")]


class MemberActivityReadState(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="activity_read_state",
    )
    # Retained as dormant schema so retiring Chat does not rewrite existing state.
    chat_last_seen_id = models.PositiveBigIntegerField(default=0)
    # Legacy Feed cursor retained to avoid rewriting existing activity state.
    feed_last_seen_id = models.PositiveBigIntegerField(default=0)
    played_last_seen_id = models.PositiveBigIntegerField(default=0)


class InviteCodeAttempt(models.Model):
    ip_digest = models.CharField(max_length=64, primary_key=True)
    failed_attempts = models.PositiveSmallIntegerField(default=0)
    window_started_at = models.DateTimeField(default=timezone.now)
    blocked_until = models.DateTimeField(null=True, blank=True)


class PasskeyAccount(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="passkey_account")
    user_handle = models.CharField(max_length=64, unique=True, default=new_passkey_user_handle)
    username_set = models.BooleanField(default=True)


class PasskeyCredential(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="passkeys")
    credential_id = models.CharField(max_length=1024, unique=True)
    public_key = models.TextField()
    sign_count = models.PositiveBigIntegerField(default=0)
    transports = models.JSONField(default=list, blank=True)
    name = models.CharField(max_length=80, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    last_used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["created_at", "pk"]

    def __str__(self):
        return f"Passkey for {self.user.get_username()}"


class AccessKeyCredential(models.Model):
    """One site-generated, revocable password for an account."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="access_key_credential",
    )
    key_digest = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(default=timezone.now)
    last_used_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Generated access key for {self.user.get_username()}"


class SiteSettings(models.Model):
    """Owner-managed settings shared by every listener."""
    aac_bitrate = models.PositiveSmallIntegerField(choices=[(96, "96 kbps"), (128, "128 kbps"), (160, "160 kbps"), (192, "192 kbps"), (256, "256 kbps")], default=192)
    player_session_limit_minutes = models.PositiveSmallIntegerField(
        default=120,
        validators=[
            MinValueValidator(PLAYER_SESSION_LIMIT_MINUTES_MIN),
            MaxValueValidator(PLAYER_SESSION_LIMIT_MINUTES_MAX),
        ],
    )
    id = models.PositiveSmallIntegerField(primary_key=True, default=1, editable=False)
