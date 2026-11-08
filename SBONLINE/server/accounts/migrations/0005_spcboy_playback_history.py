import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0004_passkey_credentials"),
    ]

    operations = [
        migrations.CreateModel(
            name="SPCBOYPlaybackHistory",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("playback_id", models.UUIDField()),
                ("track_id", models.CharField(max_length=64)),
                ("title", models.CharField(max_length=300)),
                ("game", models.CharField(max_length=300)),
                ("console", models.CharField(max_length=100)),
                ("played_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="spcboy_playback_history", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-played_at", "-pk"],
                "constraints": [
                    models.UniqueConstraint(fields=("user", "playback_id"), name="unique_spcboy_playback_event"),
                ],
            },
        ),
    ]
