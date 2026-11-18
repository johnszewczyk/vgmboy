import json
import uuid
from datetime import timedelta, timezone as datetime_timezone

from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from .models import AccessKeyCredential, Invitation, MemberProfile, MonthlyUsage, PasskeyCredential, SPCBOYPlaybackHistory, SiteSettings


@override_settings(SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=["testserver"])
class MobileAdminTests(TestCase):
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

    def test_mobile_nav_admin_tab_only_shown_for_superuser_and_desktop_topbar_untouched(self):
        self.client.force_login(self.member)
        member_page = self.client.get(reverse("spcboy"))
        self.assertEqual(member_page.status_code, 200)
        self.assertNotContains(member_page, 'data-mobile-app-page="admin"')
        self.assertNotContains(member_page, 'id="spcboy-mobile-screen-admin"')
        self.assertNotContains(member_page, 'data-nav-key="admin"')

        self.client.force_login(self.owner)
        owner_page = self.client.get(reverse("spcboy"))
        self.assertEqual(owner_page.status_code, 200)
        self.assertContains(owner_page, 'data-mobile-app-page="admin"')
        self.assertContains(owner_page, 'id="spcboy-mobile-screen-admin"')
        # Desktop navigation remains untouched per requirement.
        self.assertNotContains(owner_page, 'data-nav-key="admin"')

    def test_spcboy_admin_endpoint_requires_superuser(self):
        self.client.force_login(self.member)
        self.assertEqual(self.client.get(reverse("spcboy_admin")).status_code, 403)
        self.assertEqual(
            self.client.post(
                reverse("spcboy_admin"),
                json.dumps({"action": "create-invite"}),
                content_type="application/json",
            ).status_code,
            403,
        )

    def test_spcboy_admin_json_actions_cover_controls_invites_accounts_and_profile(self):
        self.client.force_login(self.owner)
        url = reverse("spcboy_admin")

        initial = self.client.get(url)
        self.assertEqual(initial.status_code, 200)
        payload = initial.json()
        by_id = {row["id"]: row for row in payload["accounts"]}
        self.assertFalse(by_id[self.owner.pk]["canManage"])
        self.assertFalse(by_id[self.persona.pk]["canManage"])
        self.assertTrue(by_id[self.member.pk]["canManage"])

        # Save site controls
        res = self.client.post(
            url,
            json.dumps({"action": "save-site-settings", "aacBitrate": 256, "sessionLimitMinutes": 90}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        settings_obj = SiteSettings.objects.get(pk=1)
        self.assertEqual(settings_obj.aac_bitrate, 256)
        self.assertEqual(settings_obj.player_session_limit_minutes, 90)

        # Create + revoke member invite
        res = self.client.post(url, json.dumps({"action": "create-invite"}), content_type="application/json")
        self.assertEqual(res.status_code, 200)
        created = res.json()["createdInvite"]
        self.assertFalse(created["isRecovery"])
        self.assertTrue(created["joinUrl"].endswith("/join/"))
        invite = Invitation.objects.get(selector=created["selector"])
        self.assertTrue(invite.is_open)

        res = self.client.post(
            url,
            json.dumps({"action": "revoke-invite", "selector": str(invite.selector)}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        invite.refresh_from_db()
        self.assertIsNotNone(invite.revoked_at)

        # Suspend + reactivate + recovery invite + delete member
        res = self.client.post(
            url,
            json.dumps({"action": "toggle-user", "userId": self.member.pk}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.member.refresh_from_db()
        self.assertFalse(self.member.is_active)

        res = self.client.post(
            url,
            json.dumps({"action": "toggle-user", "userId": self.member.pk}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.member.refresh_from_db()
        self.assertTrue(self.member.is_active)

        res = self.client.post(
            url,
            json.dumps({"action": "recovery-invite", "userId": self.member.pk}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        recovery = res.json()["createdInvite"]
        self.assertTrue(recovery["isRecovery"])
        self.assertIn(f"/join/{recovery['selector']}/", recovery["joinUrl"])

        res = self.client.post(
            url,
            json.dumps({"action": "delete-user", "userId": self.member.pk}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertFalse(get_user_model().objects.filter(pk=self.member.pk).exists())

        # Refuses managing persona
        persona_del = self.client.post(
            url,
            json.dumps({"action": "delete-user", "userId": self.persona.pk}),
            content_type="application/json",
        )
        self.assertEqual(persona_del.status_code, 404)

        # Display name + login password
        res = self.client.post(
            url,
            json.dumps({"action": "update-display-name", "displayName": "Mobile Owner"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["selfAccount"]["displayName"], "Mobile Owner")

        res = self.client.post(url, json.dumps({"action": "generate-login-password"}), content_type="application/json")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["createdLoginPassword"])
        self.assertTrue(AccessKeyCredential.objects.filter(user=self.owner).exists())

        res = self.client.post(url, json.dumps({"action": "revoke-login-password"}), content_type="application/json")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(AccessKeyCredential.objects.filter(user=self.owner).exists())

    def test_spcboy_admin_site_stats_reports_totals_and_daily_average(self):
        now = timezone.now()
        SPCBOYPlaybackHistory.objects.create(
            user=self.owner,
            playback_id=uuid.uuid4(),
            track_id="track-1",
            title="Track 1",
            game="Game",
            console="SNES",
            played_at=now - timedelta(days=3),
        )
        SPCBOYPlaybackHistory.objects.create(
            user=self.owner,
            playback_id=uuid.uuid4(),
            track_id="track-2",
            title="Track 2",
            game="Game",
            console="SNES",
            played_at=now,
        )
        period = now.astimezone(datetime_timezone.utc).date().replace(day=1)
        MonthlyUsage.objects.create(user=self.owner, period=period, audio_bytes=2 * 1024 * 1024)

        self.client.force_login(self.owner)
        res = self.client.get(reverse("spcboy_admin"))
        self.assertEqual(res.status_code, 200)
        stats = res.json()["siteStats"]
        self.assertEqual(stats["totalPlays"], 2)
        self.assertGreaterEqual(stats["playsToday"], 1)
        self.assertAlmostEqual(stats["avgPlaysPerDay"], round(2 / 4, 1))
        self.assertEqual(stats["monthlyAudio"], "2.1 MB")

    def test_spcboy_admin_and_usage_queries_scale_in_constant_queries_across_members(self):
        from .views import _account_rows

        User = get_user_model()
        self.client.force_login(self.owner)
        baseline_response = self.client.get(reverse("spcboy_admin"))
        self.assertEqual(baseline_response.status_code, 200)

        with CaptureQueriesContext(connection) as small_ctx:
            rows_small = _account_rows([])
        small_queries = len(small_ctx)

        for idx in range(8):
            member = User.objects.create_user(username=f"extra-listener-{idx}")
            MemberProfile.objects.update_or_create(user=member, defaults={"display_name": f"Extra {idx}"})

        with CaptureQueriesContext(connection) as larger_ctx:
            rows_larger = _account_rows([])

        self.assertEqual(len(rows_larger), len(rows_small) + 8)
        self.assertEqual(len(larger_ctx), small_queries)

        # Also delete one profile so fallback _safe_member_profile path recovers cleanly without throwing.
        MemberProfile.objects.filter(user__username="extra-listener-0").delete()
        rows_recovered = _account_rows([])
        self.assertTrue(any(row.username == "extra-listener-0" and row.display_name.startswith("Player ") for row in rows_recovered))

        usage_res = self.client.get(reverse("usage"))
        self.assertEqual(usage_res.status_code, 200)
        self.assertContains(usage_res, "Extra 7")
