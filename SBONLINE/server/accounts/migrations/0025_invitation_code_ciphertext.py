from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0024_access_key_credential"),
    ]

    operations = [
        migrations.AddField(
            model_name="invitation",
            name="invitation_code_ciphertext",
            field=models.CharField(blank=True, default="", max_length=255),
        ),
    ]
