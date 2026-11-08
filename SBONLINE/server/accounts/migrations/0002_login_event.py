import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="LoginEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("event_type", models.CharField(choices=[("success", "Successful sign-in"), ("failed", "Failed sign-in")], db_index=True, max_length=10)),
                ("username", models.CharField(blank=True, max_length=64)),
                ("occurred_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("ip_address", models.GenericIPAddressField(blank=True, null=True)),
                ("user_agent", models.CharField(blank=True, max_length=512)),
                ("session_key_digest", models.CharField(blank=True, db_index=True, max_length=64, null=True)),
                ("last_seen_at", models.DateTimeField(blank=True, null=True)),
                ("ended_at", models.DateTimeField(blank=True, null=True)),
                ("end_reason", models.CharField(blank=True, max_length=16)),
            ],
            options={"ordering": ["-occurred_at", "-pk"]},
        ),
    ]
