from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0027_spcboy_recent_hidden"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="memberprofile",
            name="avatar_preset",
        ),
    ]
