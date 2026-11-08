import django.utils.timezone
from django.conf import settings
from django.db import migrations, models
from django.db.models.functions.text import Lower
import django.db.models.deletion
import accounts.models


def create_member_profiles(apps, schema_editor):
    User = apps.get_model(*settings.AUTH_USER_MODEL.split("."))
    MemberProfile = apps.get_model("accounts", "MemberProfile")
    for user in User.objects.all().iterator():
        MemberProfile.objects.get_or_create(
            user_id=user.pk,
            defaults={
                "display_name": f"Player {user.pk:03d}",
                "avatar_preset": f"pixel-{((user.pk - 1) % 6) + 1:02d}",
            },
        )
    PasskeyAccount = apps.get_model("accounts", "PasskeyAccount")
    PasskeyAccount.objects.filter(username_set=False).update(username_set=True)
    Invitation = apps.get_model("accounts", "Invitation")
    Invitation.objects.filter(is_recovery=False, username_assigned=False).update(username_assigned=True)


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0010_private_member_invite_codes"),
    ]

    operations = [
        migrations.CreateModel(
            name="MemberProfile",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("display_name", models.CharField(max_length=40)),
                ("avatar", models.FileField(blank=True, upload_to=accounts.models.member_avatar_upload_to)),
                ("avatar_preset", models.CharField(blank=True, choices=[("initials", "Initials"), ("pixel-01", "Fighter 1"), ("pixel-02", "Fighter 2"), ("pixel-03", "Fighter 3"), ("pixel-04", "Fighter 4"), ("pixel-05", "Fighter 5"), ("pixel-06", "Fighter 6")], max_length=16)),
                ("updated_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="member_profile", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["display_name", "user_id"]},
        ),
        migrations.CreateModel(
            name="FavoriteTrack",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("track_id", models.CharField(max_length=64)),
                ("added_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="favorite_tracks", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-added_at", "pk"]},
        ),
        migrations.CreateModel(
            name="CommunityPost",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("text", models.CharField(blank=True, max_length=2000)),
                ("image", models.FileField(blank=True, upload_to=accounts.models.community_image_upload_to)),
                ("created_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("updated_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="community_posts", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-created_at", "-pk"]},
        ),
        migrations.CreateModel(
            name="InviteCodeAttempt",
            fields=[
                ("ip_digest", models.CharField(max_length=64, primary_key=True, serialize=False)),
                ("failed_attempts", models.PositiveSmallIntegerField(default=0)),
                ("window_started_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("blocked_until", models.DateTimeField(blank=True, null=True)),
            ],
        ),
        migrations.AddConstraint(
            model_name="memberprofile",
            constraint=models.UniqueConstraint(Lower("display_name"), condition=~models.Q(display_name=""), name="unique_member_profile_display_name_ci"),
        ),
        migrations.AddConstraint(
            model_name="favoritetrack",
            constraint=models.UniqueConstraint(fields=("user", "track_id"), name="unique_user_favorite_track"),
        ),
        migrations.RunPython(create_member_profiles, migrations.RunPython.noop),
    ]
