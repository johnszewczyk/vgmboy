from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0007_passkey_username_setup"),
    ]

    operations = [
        migrations.AddField(
            model_name="invitation",
            name="username_assigned",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="invitation",
            name="join_link_only",
            field=models.BooleanField(default=False),
        ),
    ]
