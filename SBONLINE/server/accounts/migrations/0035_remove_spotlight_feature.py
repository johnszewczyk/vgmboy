from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0034_memberprofile_spcboy_preferences"),
    ]

    operations = [
        migrations.DeleteModel(
            name="SpotlightVote",
        ),
        migrations.DeleteModel(
            name="SpotlightPost",
        ),
        migrations.RemoveField(
            model_name="memberactivityreadstate",
            name="spotlight_last_seen_id",
        ),
    ]
