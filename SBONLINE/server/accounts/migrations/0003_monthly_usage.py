import django.utils.timezone
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0002_login_event"),
    ]

    operations = [
        migrations.CreateModel(
            name="MonthlyUsage",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("period", models.DateField(help_text="First day of the UTC month")),
                ("site_bytes", models.PositiveBigIntegerField(default=0)),
                ("media_bytes", models.PositiveBigIntegerField(default=0)),
                ("updated_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ["-period", "user__username"]},
        ),
        migrations.AddConstraint(
            model_name="monthlyusage",
            constraint=models.UniqueConstraint(fields=("user", "period"), name="unique_monthly_user_usage"),
        ),
    ]
