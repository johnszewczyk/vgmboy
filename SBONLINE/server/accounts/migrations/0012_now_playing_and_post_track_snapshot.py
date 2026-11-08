import django.utils.timezone
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0011_member_profiles_social_and_invite_throttle"),
    ]

    operations = [
        migrations.CreateModel(
            name="SPCBOYNowPlaying",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("playback_id", models.UUIDField()),
                ("track_id", models.CharField(max_length=64)),
                ("title", models.CharField(max_length=300)),
                ("game", models.CharField(max_length=300)),
                ("console", models.CharField(max_length=100)),
                ("started_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("updated_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="spcboy_now_playing", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-updated_at", "user_id"]},
        ),
        migrations.AddField(
            model_name="communitypost",
            name="listening_track_id",
            field=models.CharField(blank=True, max_length=64),
        ),
        migrations.AddField(
            model_name="communitypost",
            name="listening_title",
            field=models.CharField(blank=True, max_length=300),
        ),
        migrations.AddField(
            model_name="communitypost",
            name="listening_game",
            field=models.CharField(blank=True, max_length=300),
        ),
        migrations.AddField(
            model_name="communitypost",
            name="listening_console",
            field=models.CharField(blank=True, max_length=100),
        ),
    ]
