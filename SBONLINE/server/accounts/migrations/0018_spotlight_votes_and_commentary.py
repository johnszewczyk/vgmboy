from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0017_spotlight_posts"),
    ]

    operations = [
        migrations.AddField(
            model_name="spotlightpost",
            name="commentary",
            field=models.CharField(blank=True, max_length=1000),
        ),
        migrations.CreateModel(
            name="SpotlightVote",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("choice", models.SmallIntegerField(choices=[(1, "Thumbs up"), (-1, "Thumbs down")])),
                ("created_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("post", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="votes", to="accounts.spotlightpost")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="spotlight_votes", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddConstraint(
            model_name="spotlightvote",
            constraint=models.UniqueConstraint(fields=("user", "post"), name="unique_user_spotlight_vote"),
        ),
    ]
