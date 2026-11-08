from django.db import migrations, models
from django.db.models import Q
from django.db.models.functions import Lower


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0008_simpler_join_openings"),
    ]

    operations = [
        migrations.AddField(
            model_name="invitation",
            name="recipient_email",
            field=models.EmailField(blank=True, default="", max_length=254),
        ),
        migrations.AddConstraint(
            model_name="invitation",
            constraint=models.UniqueConstraint(
                Lower("recipient_email"),
                condition=Q(recipient_email__gt="", used_at__isnull=True, revoked_at__isnull=True),
                name="unique_open_invitation_email",
            ),
        ),
    ]
