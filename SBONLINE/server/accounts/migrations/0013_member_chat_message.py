import django.utils.timezone
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0012_now_playing_and_post_track_snapshot"),
    ]

    operations = [
        migrations.CreateModel(
            name="MemberChatMessage",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("text", models.CharField(max_length=1000)),
                ("created_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="member_chat_messages", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["pk"]},
        ),
        migrations.AddIndex(
            model_name="memberchatmessage",
            index=models.Index(fields=["user", "created_at"], name="chat_user_time_idx"),
        ),
    ]
