from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0013_member_chat_message"),
    ]

    operations = [
        migrations.AlterField(
            model_name="memberprofile",
            name="avatar_preset",
            field=models.CharField(
                blank=True,
                choices=[
                    ("initials", "Initials"),
                    ("pixel-01", "Avatar 1"),
                    ("pixel-02", "Avatar 2"),
                    ("pixel-03", "Avatar 3"),
                    ("pixel-04", "Avatar 4"),
                    ("pixel-05", "Avatar 5"),
                    ("pixel-06", "Avatar 6"),
                    ("pixel-07", "Avatar 7"),
                    ("pixel-08", "Avatar 8"),
                    ("pixel-09", "Avatar 9"),
                    ("pixel-10", "Avatar 10"),
                ],
                max_length=16,
            ),
        ),
    ]
