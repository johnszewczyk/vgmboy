from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0015_member_profile_initials_only"),
    ]

    operations = [
        migrations.CreateModel(
            name="MemberActivityReadState",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("chat_last_seen_id", models.PositiveBigIntegerField(default=0)),
                ("feed_last_seen_id", models.PositiveBigIntegerField(default=0)),
                ("played_last_seen_id", models.PositiveBigIntegerField(default=0)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="activity_read_state", to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
