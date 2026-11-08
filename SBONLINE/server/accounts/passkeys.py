import hmac
import json

from webauthn import (
    base64url_to_bytes,
    generate_authentication_options,
    generate_registration_options,
    options_to_json,
    verify_authentication_response,
    verify_registration_response,
)
from webauthn.helpers import bytes_to_base64url
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    PublicKeyCredentialDescriptor,
    ResidentKeyRequirement,
    UserVerificationRequirement,
)

from .models import PasskeyAccount


RP_ID = "admin.pre-calc.com"
RP_NAME = "Pre-Calc Private"
EXPECTED_ORIGIN = "https://admin.pre-calc.com"
CEREMONY_TIMEOUT_MS = 60_000


def registration_options(user):
    account, _ = PasskeyAccount.objects.get_or_create(user=user)
    account_name = user.get_username() if account.username_set else "Pre-Calc Friend"
    excluded = [
        PublicKeyCredentialDescriptor(id=base64url_to_bytes(item.credential_id))
        for item in user.passkeys.all()
    ]
    options = generate_registration_options(
        rp_id=RP_ID,
        rp_name=RP_NAME,
        user_id=base64url_to_bytes(account.user_handle),
        user_name=account_name,
        user_display_name=account_name,
        authenticator_selection=AuthenticatorSelectionCriteria(
            resident_key=ResidentKeyRequirement.REQUIRED,
            user_verification=UserVerificationRequirement.REQUIRED,
        ),
        exclude_credentials=excluded,
        timeout=CEREMONY_TIMEOUT_MS,
    )
    return json.loads(options_to_json(options)), bytes_to_base64url(options.challenge)


def authentication_options():
    options = generate_authentication_options(
        rp_id=RP_ID,
        user_verification=UserVerificationRequirement.REQUIRED,
        timeout=CEREMONY_TIMEOUT_MS,
    )
    return json.loads(options_to_json(options)), bytes_to_base64url(options.challenge)


def verify_registration(payload, user, expected_challenge):
    verified = verify_registration_response(
        credential=payload,
        expected_challenge=base64url_to_bytes(expected_challenge),
        expected_rp_id=RP_ID,
        expected_origin=EXPECTED_ORIGIN,
        require_user_verification=True,
    )
    credential_id = bytes_to_base64url(verified.credential_id)
    return {
        "user": user,
        "credential_id": credential_id,
        "public_key": bytes_to_base64url(verified.credential_public_key),
        "sign_count": verified.sign_count,
        "transports": payload.get("response", {}).get("transports", []),
    }


def verify_authentication(payload, credential, account, expected_challenge):
    user_handle = payload.get("response", {}).get("userHandle")
    if not user_handle or not hmac.compare_digest(user_handle, account.user_handle):
        raise ValueError("The passkey did not identify its account.")
    return verify_authentication_response(
        credential=payload,
        expected_challenge=base64url_to_bytes(expected_challenge),
        expected_rp_id=RP_ID,
        expected_origin=EXPECTED_ORIGIN,
        credential_public_key=base64url_to_bytes(credential.public_key),
        credential_current_sign_count=credential.sign_count,
        require_user_verification=True,
    )
