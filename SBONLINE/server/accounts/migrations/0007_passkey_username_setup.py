from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0006_passwordless_passkeys"),
    ]

    operations = [
        migrations.AddField(
            model_name="passkeyaccount",
            name="username_set",
            field=models.BooleanField(default=True),
        ),
    ]
