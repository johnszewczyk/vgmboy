from django.db import migrations
from django.utils import timezone


def revoke_open_member_invitations(apps, schema_editor):
    Invitation = apps.get_model("accounts", "Invitation")
    Invitation.objects.filter(
        is_recovery=False,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=timezone.now())


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0009_email_bound_member_invites"),
    ]

    operations = [
        migrations.RunPython(revoke_open_member_invitations, migrations.RunPython.noop),
        migrations.RemoveConstraint(
            model_name="invitation",
            name="unique_open_invitation_email",
        ),
        migrations.RemoveField(
            model_name="invitation",
            name="recipient_email",
        ),
        migrations.RemoveField(
            model_name="invitation",
            name="join_link_only",
        ),
    ]
