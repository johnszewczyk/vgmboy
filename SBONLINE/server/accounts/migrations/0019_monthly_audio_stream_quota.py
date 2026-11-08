from django.db import migrations, models
from django.db.models import F


def backfill_audio_usage(apps, schema_editor):
    MonthlyUsage = apps.get_model("accounts", "MonthlyUsage")
    MonthlyUsage.objects.update(audio_bytes=F("media_bytes"))


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0018_spotlight_votes_and_commentary"),
    ]

    operations = [
        migrations.AddField(
            model_name="monthlyusage",
            name="audio_bytes",
            field=models.PositiveBigIntegerField(default=0),
        ),
        migrations.RunPython(backfill_audio_usage, migrations.RunPython.noop),
    ]
