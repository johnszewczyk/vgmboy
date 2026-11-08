import sys

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import Invitation
from accounts.views import _decrypt_invitation_code, _digest, _encrypt_invitation_code


INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class Command(BaseCommand):
    help = "Attach a recovered legacy invitation code to its digest-matched record."

    def handle(self, *args, **options):
        supplied = sys.stdin.readline()
        if not supplied:
            raise CommandError("Provide the recovered invitation code through stdin.")

        code = supplied.strip().upper()
        if len(code) != 8 or any(character not in INVITE_ALPHABET for character in code):
            raise CommandError("The supplied value is not a valid member invitation code.")

        with transaction.atomic():
            matching_ids = list(
                Invitation.objects.filter(
                    invitation_code_digest=_digest(code),
                    is_recovery=False,
                ).values_list("pk", flat=True)[:2]
            )
            if len(matching_ids) != 1:
                raise CommandError("No unique matching member invitation was found; no record was changed.")

            invitation = Invitation.objects.select_for_update().get(pk=matching_ids[0])
            stored_code = _decrypt_invitation_code(invitation)
            if stored_code == code:
                self.stdout.write("The matching invitation already has its encrypted code.")
                return
            if invitation.invitation_code_ciphertext:
                raise CommandError("The matching invitation has unreadable encrypted data; no record was changed.")

            invitation.invitation_code_ciphertext = _encrypt_invitation_code(code)
            invitation.save(update_fields=["invitation_code_ciphertext"])

        self.stdout.write("Verified the matching invitation and stored its code encrypted.")
