from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0032_player_session_limit"),
    ]

    operations = [
        migrations.AlterField(
            model_name="sitesettings",
            name="player_session_limit_minutes",
            field=models.PositiveSmallIntegerField(
                default=120,
                validators=[MinValueValidator(1), MaxValueValidator(1440)],
            ),
        ),
    ]
