from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from accounts.models import Invitation
from accounts.views import _create_invitation


class Command(BaseCommand):
    help = "Create a one-use passkey recovery invitation for an existing account."

    def add_arguments(self, parser):
        parser.add_argument("account_label")

    def handle(self, *args, **options):
        account_label = options["account_label"].strip()
        user = get_user_model().objects.filter(username__iexact=account_label, is_active=True).first()
        if user is None:
            raise CommandError("No active account has that label.")

        Invitation.objects.filter(
            username__iexact=user.username,
            is_recovery=True,
            used_at__isnull=True,
            revoked_at__isnull=True,
        ).update(revoked_at=timezone.now())
        invitation, code = _create_invitation(
            username=user.username,
            creator="server operator",
            is_recovery=True,
        )
        self.stdout.write(f"Recovery URL: https://admin.pre-calc.com/join/{invitation.selector}/")
        self.stdout.write(f"One-time invitation code (shown once): {code}")
        self.stdout.write(f"Expires: {invitation.expires_at.isoformat()}")
        self.stdout.write("Verify the recipient separately and send the URL and code through different channels.")
