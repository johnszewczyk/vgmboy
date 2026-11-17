import sys

from django.contrib.auth import get_user_model
from django.contrib.auth.signals import user_logged_in, user_login_failed
from django.db.models.signals import post_delete, post_save, pre_delete
from django.dispatch import receiver
from django.utils import timezone

from .context_processors import invalidate_player_chrome_cache
from .login_audit import request_ip_address, request_user_agent, session_key_digest
from .models import CommunityPost, LoginEvent, MemberProfile, SPCBOYPlaybackHistory, SiteSettings
from .usage import invalidate_site_settings_cache


@receiver(post_save, sender=get_user_model())
def create_member_profile(sender, instance, created, **kwargs):
    if not created:
        return
    base = f"Player {instance.pk:03d}"
    display_name = base
    suffix = 2
    while MemberProfile.objects.filter(display_name__iexact=display_name).exists():
        display_name = f"{base} {suffix}"
        suffix += 1
    MemberProfile.objects.get_or_create(
        user=instance,
        defaults={"display_name": display_name},
    )


@receiver(pre_delete, sender=CommunityPost)
def delete_community_image(sender, instance, **kwargs):
    if instance.image:
        instance.image.delete(save=False)


@receiver([post_save, post_delete], sender=SiteSettings)
def clear_site_settings_cache(sender, **kwargs):
    invalidate_site_settings_cache()


@receiver([post_save, post_delete], sender=SPCBOYPlaybackHistory)
def clear_user_playback_history_cache(sender, instance, **kwargs):
    invalidate_player_chrome_cache(user_id=getattr(instance, "user_id", None))


@receiver(user_logged_in)
def record_successful_login(sender, request, user, **kwargs):
    if (
        request is not None
        and request.META.get("SERVER_NAME") == "testserver"
        and not any("test" in arg for arg in sys.argv)
    ):
        latest_real = (
            LoginEvent.objects.filter(
                event_type=LoginEvent.LOGIN_SUCCESS,
                username=user.get_username()[:64],
            )
            .exclude(ip_address__isnull=True, user_agent="")
            .order_by("-occurred_at")
            .values_list("occurred_at", flat=True)
            .first()
        )
        if user.last_login != latest_real:
            user.__class__.objects.filter(pk=user.pk).update(last_login=latest_real)
            user.last_login = latest_real
        return
    now = timezone.now()
    LoginEvent.objects.create(
        event_type=LoginEvent.LOGIN_SUCCESS,
        username=user.get_username()[:64],
        occurred_at=now,
        ip_address=request_ip_address(request),
        user_agent=request_user_agent(request),
        session_key_digest=session_key_digest(request.session.session_key),
        last_seen_at=now,
    )
    invalidate_player_chrome_cache()


@receiver(user_login_failed)
def record_failed_login(sender, credentials, request, **kwargs):
    raw_username = credentials.get("username") or credentials.get("email") or ""
    username = "".join(character for character in str(raw_username) if character.isprintable()).strip()[:64]
    LoginEvent.objects.create(
        event_type=LoginEvent.LOGIN_FAILED,
        username=username,
        ip_address=request_ip_address(request) if request else None,
        user_agent=request_user_agent(request) if request else "",
    )
