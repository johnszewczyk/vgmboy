import re

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from accounts.models import Invitation
from accounts.views import _create_invitation


class Command(BaseCommand):
    help = "Open a two-minute, one-use join for the first private-space administrator."

    def add_arguments(self, parser):
        parser.add_argument("account_label")

    def handle(self, *args, **options):
        username = options["account_label"].strip().lower()
        if not re.fullmatch(r"[a-zA-Z0-9_.-]{3,64}", username):
            raise CommandError("Use a 3–64 character account label with letters, numbers, periods, underscores, or hyphens.")

        user_model = get_user_model()
        if user_model.objects.filter(is_superuser=True).exists():
            raise CommandError("An administrator already exists.")
        if user_model.objects.filter(username__iexact=username).exists():
            raise CommandError("That account label already exists.")

        Invitation.objects.filter(
            is_admin=True,
            used_at__isnull=True,
            revoked_at__isnull=True,
        ).update(revoked_at=timezone.now())
        invitation, _ = _create_invitation(
            username=username,
            creator="bootstrap",
            is_admin=True,
        )
        self.stdout.write(f"Enrollment URL: https://admin.pre-calc.com/join/{invitation.selector}/")
        self.stdout.write(f"Closes: {invitation.expires_at.isoformat()}")
        self.stdout.write("The link accepts one join and requires passkey registration.")
