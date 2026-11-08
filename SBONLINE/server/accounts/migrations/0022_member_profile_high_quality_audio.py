from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0021_favorite_album"),
    ]

    operations = [
        migrations.AddField(
            model_name="memberprofile",
            name="high_quality_audio",
            field=models.BooleanField(default=False),
        ),
    ]
