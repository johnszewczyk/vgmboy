import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0026_memberprofile_theme_preference"),
    ]

    operations = [
        migrations.CreateModel(
            name="SPCBOYRecentHidden",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("hidden_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("event", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="hidden_from_recents", to="accounts.spcboyplaybackhistory")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="spcboy_hidden_recents", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "constraints": [
                    models.UniqueConstraint(fields=("user", "event"), name="unique_spcboy_hidden_recent"),
                ],
            },
        ),
    ]
