from django.db import migrations, models


def migrate_presets_to_initials(apps, schema_editor):
    MemberProfile = apps.get_model("accounts", "MemberProfile")
    profiles = MemberProfile.objects.filter(avatar_preset__startswith="pixel-")
    profiles.exclude(avatar="").update(avatar_preset="")
    profiles.filter(avatar="").update(avatar_preset="initials")


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0014_member_profile_avatar_presets"),
    ]

    operations = [
        migrations.RunPython(migrate_presets_to_initials, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="memberprofile",
            name="avatar_preset",
            field=models.CharField(
                blank=True,
                choices=[("initials", "Initials")],
                max_length=16,
            ),
        ),
    ]
