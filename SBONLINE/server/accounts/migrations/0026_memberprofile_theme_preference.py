from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0025_invitation_code_ciphertext"),
    ]

    operations = [
        migrations.AddField(
            model_name="memberprofile",
            name="theme_preference",
            field=models.CharField(
                choices=[("system", "Use device setting"), ("dark", "Dark"), ("light", "Light")],
                default="system",
                max_length=8,
            ),
        ),
    ]
