from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0033_flexible_player_session_limit"),
    ]

    operations = [
        migrations.AddField(
            model_name="memberprofile",
            name="spcboy_preferences",
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
