import uuid

import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Invitation",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("selector", models.UUIDField(default=uuid.uuid4, editable=False, unique=True)),
                ("username", models.CharField(max_length=64)),
                ("passkey_digest", models.CharField(max_length=64)),
                ("is_admin", models.BooleanField(default=False)),
                ("is_reset", models.BooleanField(default=False)),
                ("created_by_username", models.CharField(max_length=150)),
                ("created_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("expires_at", models.DateTimeField()),
                ("used_at", models.DateTimeField(blank=True, null=True)),
                ("revoked_at", models.DateTimeField(blank=True, null=True)),
                ("failed_attempts", models.PositiveSmallIntegerField(default=0)),
            ],
            options={"ordering": ["-created_at"]},
        ),
    ]
