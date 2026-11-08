from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0028_remove_memberprofile_avatar_preset")]
    operations = [migrations.CreateModel(
        name="SiteSettings",
        fields=[
            ("id", models.PositiveSmallIntegerField(default=1, editable=False, primary_key=True, serialize=False)),
            ("mp3_quality", models.CharField(choices=[("128", "128 kbps"), ("192", "192 kbps"), ("256", "256 kbps"), ("320", "320 kbps"), ("v0", "V0 · highest-quality variable bitrate")], default="256", max_length=3)),
        ],
    )]
