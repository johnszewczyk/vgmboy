import json
import re
import uuid
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import Client, TestCase, override_settings
from .models import PasskeyCredential, SPCBOYNowPlaying


@override_settings(SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=['testserver'])
class ListeningPresenceTests(TestCase):
    def test_persistent_player_token_authorizes_presence_on_formless_pages(self):
        user = get_user_model().objects.create_user(username='listener')
        PasskeyCredential.objects.create(user=user, credential_id='test-only', public_key='test-only')
        client = Client(enforce_csrf_checks=True)
        client.force_login(user)
        page = client.get('/history/')
        self.assertEqual(page.status_code, 200)
        token = re.search(r'id="site-player-csrf"[^>]*>.*?value="([^"]+)"', page.content.decode(), re.S)[1]
        self.assertTrue(client.cookies['csrftoken']['httponly'])
        data = json.dumps({'status':'playing','playbackId':str(uuid.uuid4()),'trackId':'vgm-fixture'})
        with patch('accounts.views._catalog_track_index', return_value={'vgm-fixture':{'title':'VGM fixture','game':'Fixture','console':'Arcade'}}):
            self.assertEqual(client.post('/spcboy/now-playing.json', data, content_type='application/json').status_code,403)
            self.assertEqual(client.post('/spcboy/now-playing.json', data, content_type='application/json',HTTP_X_CSRFTOKEN=token).status_code,200)
            started = SPCBOYNowPlaying.objects.get(user=user).started_at
            with patch('accounts.views._spcboy_catalog_data', side_effect=AssertionError('heartbeat rebuilt catalog')):
                self.assertEqual(client.post('/spcboy/now-playing.json', data, content_type='application/json', HTTP_X_CSRFTOKEN=token).status_code,200)
            self.assertEqual(SPCBOYNowPlaying.objects.get(user=user).started_at,started)
            presence = client.get('/history/now-playing.json').json()
        self.assertEqual(len(presence['members']),1)
        card = presence['members'][0]['cardHtml']
        self.assertEqual(card.count('class="track-card-status"'),1)
        self.assertIn('class="track-card-main"',card)
        self.assertIn('VGM fixture',card)
        self.assertEqual(presence['members'][0]['nowPlaying']['trackId'],'vgm-fixture')
