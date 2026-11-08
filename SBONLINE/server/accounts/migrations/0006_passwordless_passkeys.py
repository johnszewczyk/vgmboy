from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.db import migrations


def retire_passwords(apps, schema_editor):
    User = apps.get_model("auth", "User")
    using = schema_editor.connection.alias
    users = User.objects.using(using).exclude(password__startswith="!")
    for user_id in users.values_list("pk", flat=True):
        User.objects.using(using).filter(pk=user_id).update(password=make_password(None))


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0005_spcboy_playback_history"),
    ]

    operations = [
        migrations.RenameField(
            model_name="invitation",
            old_name="is_reset",
            new_name="is_recovery",
        ),
        migrations.RenameField(
            model_name="invitation",
            old_name="passkey_digest",
            new_name="invitation_code_digest",
        ),
        migrations.RunPython(retire_passwords, migrations.RunPython.noop),
    ]
