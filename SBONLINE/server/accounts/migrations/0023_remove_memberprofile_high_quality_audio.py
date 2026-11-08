from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0022_member_profile_high_quality_audio"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="memberprofile",
            name="high_quality_audio",
        ),
    ]
