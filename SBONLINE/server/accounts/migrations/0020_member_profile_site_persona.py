from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0019_monthly_audio_stream_quota"),
    ]

    operations = [
        migrations.AddField(
            model_name="memberprofile",
            name="is_site_persona",
            field=models.BooleanField(default=False),
        ),
    ]
