from django.contrib.auth import get_user_model
from django.contrib.messages.storage.fallback import FallbackStorage
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory, TestCase

from .forms import SiteSettingsForm
from .models import SiteSettings
from .views import member_profile


class StreamQualityTests(TestCase):
    def test_global_aac_bitrate_is_validated(self):
        self.assertTrue(SiteSettingsForm({"aac_bitrate":"192", "player_session_limit_minutes":"120"}).is_valid())
        self.assertFalse(SiteSettingsForm({"aac_bitrate":"999", "player_session_limit_minutes":"120"}).is_valid())

    def request(self, user):
        request = RequestFactory().post("/profile/?tab=site", {"action": "site-settings", "aac_bitrate": "256", "player_session_limit_minutes": "120"})
        request.user = user
        request.session = {}
        request._messages = FallbackStorage(request)
        return request

    def test_member_cannot_change_site_quality(self):
        user = get_user_model().objects.create_user(username="listener")
        with self.assertRaises(PermissionDenied):
            member_profile(self.request(user))
        self.assertFalse(SiteSettings.objects.exists())

    def test_owner_save_is_independent_of_profile_form(self):
        user = get_user_model().objects.create_user(username="owner", is_superuser=True)
        response = member_profile(self.request(user))
        self.assertEqual(response.status_code, 302)
        self.assertTrue(response.url.endswith("/accounts/"))
        self.assertEqual(SiteSettings.objects.get(pk=1).aac_bitrate, 256)

    def test_audio_claim_is_atomic_and_caps_final_chunk(self):
        from .models import MonthlyUsage
        from .usage import claim_audio_stream_bytes, MONTHLY_AUDIO_STREAM_LIMIT_BYTES, _month_start
        user = get_user_model().objects.create_user(username="quota")
        self.assertEqual(claim_audio_stream_bytes(user.pk,4096),4096)
        usage = MonthlyUsage.objects.get(user=user,period=_month_start())
        usage.audio_bytes = MONTHLY_AUDIO_STREAM_LIMIT_BYTES-100
        usage.save()
        self.assertEqual(claim_audio_stream_bytes(user.pk,4096),100)
        self.assertEqual(claim_audio_stream_bytes(user.pk,4096),0)
