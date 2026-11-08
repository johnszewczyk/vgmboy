import accounts.models
import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0003_monthly_usage"),
    ]

    operations = [
        migrations.CreateModel(
            name="PasskeyAccount",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("user_handle", models.CharField(default=accounts.models.new_passkey_user_handle, max_length=64, unique=True)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="passkey_account", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="PasskeyCredential",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("credential_id", models.CharField(max_length=1024, unique=True)),
                ("public_key", models.TextField()),
                ("sign_count", models.PositiveBigIntegerField(default=0)),
                ("transports", models.JSONField(blank=True, default=list)),
                ("name", models.CharField(blank=True, max_length=80)),
                ("created_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("last_used_at", models.DateTimeField(blank=True, null=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="passkeys", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["created_at", "pk"]},
        ),
    ]
