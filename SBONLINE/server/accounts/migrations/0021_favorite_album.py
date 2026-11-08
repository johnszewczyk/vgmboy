from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0020_member_profile_site_persona"),
    ]

    operations = [
        migrations.CreateModel(
            name="FavoriteAlbum",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("album_id", models.CharField(max_length=32)),
                ("added_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="favorite_albums", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-added_at", "pk"],
                "constraints": [
                    models.UniqueConstraint(fields=("user", "album_id"), name="unique_user_favorite_album"),
                ],
            },
        ),
    ]
