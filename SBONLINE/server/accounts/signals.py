from django.contrib.auth import get_user_model
from django.contrib.auth.signals import user_logged_in, user_login_failed
from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver
from django.utils import timezone

from .login_audit import request_ip_address, request_user_agent, session_key_digest
from .models import CommunityPost, LoginEvent, MemberProfile


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


@receiver(pre_delete, sender=MemberProfile)
def delete_member_avatar(sender, instance, **kwargs):
    if instance.avatar:
        instance.avatar.delete(save=False)


@receiver(pre_delete, sender=CommunityPost)
def delete_community_image(sender, instance, **kwargs):
    if instance.image:
        instance.image.delete(save=False)


@receiver(user_logged_in)
def record_successful_login(sender, request, user, **kwargs):
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
