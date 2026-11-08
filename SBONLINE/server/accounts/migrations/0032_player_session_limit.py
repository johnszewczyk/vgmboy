from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0031_aac_only"),
    ]

    operations = [
        migrations.AddField(
            model_name="sitesettings",
            name="player_session_limit_minutes",
            field=models.PositiveSmallIntegerField(
                choices=[
                    (30, "30 minutes"),
                    (60, "60 minutes"),
                    (90, "90 minutes"),
                    (120, "120 minutes"),
                ],
                default=120,
            ),
        ),
    ]
