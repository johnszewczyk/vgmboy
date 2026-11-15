from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from .models import Invitation, MemberProfile, PasskeyCredential, SiteSettings


@override_settings(SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=["testserver"])
class AdminNavigationAndControlsTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="owner", is_superuser=True, is_staff=True)
        self.member = User.objects.create_user(username="listener")
        PasskeyCredential.objects.create(user=self.owner, credential_id="owner-key", public_key="owner-key")
        PasskeyCredential.objects.create(user=self.member, credential_id="member-key", public_key="member-key")
        self.persona = User.objects.create_user(username="persona")
        MemberProfile.objects.update_or_create(
            user=self.persona,
            defaults={"display_name": "System Persona", "is_site_persona": True},
        )

    def test_admin_link_shown_in_navbar_only_for_superuser(self):
        self.client.force_login(self.member)
        member_page = self.client.get(reverse("member_profile"))
        self.assertEqual(member_page.status_code, 200)
        self.assertNotContains(member_page, 'data-nav-key="admin"')

        self.client.force_login(self.owner)
        owner_page = self.client.get(reverse("member_profile"))
        self.assertEqual(owner_page.status_code, 200)
        self.assertContains(owner_page, 'data-nav-key="admin"')
        self.assertContains(owner_page, reverse("accounts"))
        self.assertContains(owner_page, 'action="%s"' % reverse("logout"))

    def test_accounts_page_renders_subnav_site_controls_member_actions_and_invites(self):
        self.client.force_login(self.owner)
        response = self.client.get(reverse("accounts"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'aria-label="Admin sections"')
        self.assertContains(response, reverse("usage"))
        self.assertContains(response, reverse("site_log"))
        self.assertContains(response, reverse("create_invite"))
        self.assertContains(response, reverse("toggle_user", args=[self.member.pk]))
        self.assertContains(response, reverse("create_passkey_recovery_invite", args=[self.member.pk]))
        self.assertContains(response, reverse("delete_user", args=[self.member.pk]))
        # Owner and site persona cards must not render suspend/recovery/delete actions.
        self.assertNotContains(response, reverse("toggle_user", args=[self.owner.pk]))
        self.assertNotContains(response, reverse("toggle_user", args=[self.persona.pk]))
        self.assertNotContains(response, reverse("delete_user", args=[self.persona.pk]))

    def test_owner_can_create_revoke_invite_toggle_recover_delete_and_save_settings(self):
        self.client.force_login(self.owner)

        settings_response = self.client.post(
            reverse("accounts"),
            {"action": "site-settings", "aac_bitrate": "256", "player_session_limit_minutes": "90"},
        )
        self.assertRedirects(settings_response, reverse("accounts"))
        settings_obj = SiteSettings.objects.get(pk=1)
        self.assertEqual(settings_obj.aac_bitrate, 256)
        self.assertEqual(settings_obj.player_session_limit_minutes, 90)

        invite_response = self.client.post(reverse("create_invite"), follow=True)
        self.assertEqual(invite_response.status_code, 200)
        self.assertContains(invite_response, "Member invite code ready")
        invite = Invitation.objects.get(is_recovery=False)
        self.assertTrue(invite.is_open)

        accounts_with_invite = self.client.get(reverse("accounts"))
        self.assertContains(accounts_with_invite, reverse("revoke_invite", args=[invite.selector]))

        revoke_response = self.client.post(
            reverse("revoke_invite", args=[invite.selector]),
            {"return_to": "accounts"},
        )
        self.assertRedirects(revoke_response, reverse("accounts"))
        invite.refresh_from_db()
        self.assertIsNotNone(invite.revoked_at)

        toggle_response = self.client.post(reverse("toggle_user", args=[self.member.pk]))
        self.assertRedirects(toggle_response, reverse("accounts"))
        self.member.refresh_from_db()
        self.assertFalse(self.member.is_active)

        reactivate_response = self.client.post(reverse("toggle_user", args=[self.member.pk]))
        self.assertRedirects(reactivate_response, reverse("accounts"))
        self.member.refresh_from_db()
        self.assertTrue(self.member.is_active)

        recovery_response = self.client.post(reverse("create_passkey_recovery_invite", args=[self.member.pk]), follow=True)
        self.assertEqual(recovery_response.status_code, 200)
        self.assertContains(recovery_response, "Passkey recovery invitation created")

        delete_confirm = self.client.get(reverse("delete_user", args=[self.member.pk]))
        self.assertEqual(delete_confirm.status_code, 200)
        delete_post = self.client.post(reverse("delete_user", args=[self.member.pk]))
        self.assertRedirects(delete_post, reverse("accounts"))
        self.assertFalse(get_user_model().objects.filter(pk=self.member.pk).exists())
