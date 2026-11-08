from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0016_member_activity_read_state"),
    ]

    operations = [
        migrations.AddField(
            model_name="memberactivityreadstate",
            name="spotlight_last_seen_id",
            field=models.PositiveBigIntegerField(default=0),
        ),
        migrations.CreateModel(
            name="SpotlightPost",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("track_id", models.CharField(max_length=64)),
                ("title", models.CharField(max_length=300)),
                ("game", models.CharField(max_length=300)),
                ("console", models.CharField(max_length=100)),
                ("duration_seconds", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="spotlight_posts", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-created_at", "-pk"]},
        ),
    ]
