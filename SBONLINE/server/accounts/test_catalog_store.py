import json
import tempfile
import uuid
from pathlib import Path
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, TestCase, override_settings

from accounts.catalog_search import build_catalog_index, get_track_audio_source
from accounts.models import FavoriteAlbum, FavoriteTrack, SPCBOYPlaybackHistory
from accounts.spcboy_gallery import spcboy_album_id


@override_settings(SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=["testserver"])
class CatalogStoreTests(TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        root = Path(self.temp_dir.name)
        self.media_root = root / "media"
        self.gallery_root = self.media_root / "gallery-cache"
        self.index_path = root / "spcboy-search.sqlite3"
        self.media_root.mkdir(parents=True, exist_ok=True)
        self.gallery_root.mkdir(parents=True, exist_ok=True)

        self.album_id = spcboy_album_id("Super Nintendo", "Chrono Trigger")
        self.catalog = {
            "consoles": [
                {
                    "name": "Super Nintendo",
                    "games": [
                        {
                            "name": "Chrono Trigger",
                            "tracks": [
                                {"id": "ct-1", "title": "Presentiment"},
                                {"id": "ct-2", "title": "Chrono Trigger"},
                            ],
                        },
                    ],
                },
            ],
            "tracks": {
                "ct-1": {
                    "archive": "snes/ct.7z",
                    "member": "01 Presentiment.spc",
                    "trackIndex": 0,
                    "playMilliseconds": 90000,
                    "fadeMilliseconds": 5000,
                    "title": "Presentiment",
                    "artist": "Yasunori Mitsuda",
                    "year": "1995",
                    "dumper": "Datschge",
                    "game": "Chrono Trigger",
                    "console": "Super Nintendo",
                },
                "ct-2": {
                    "archive": "snes/ct.7z",
                    "member": "02 Chrono Trigger.spc",
                    "trackIndex": 0,
                    "playMilliseconds": 180000,
                    "fadeMilliseconds": 5000,
                    "title": "Chrono Trigger",
                    "artist": "Yasunori Mitsuda",
                    "year": "1995",
                    "dumper": "Datschge",
                    "game": "Chrono Trigger",
                    "console": "Super Nintendo",
                },
            },
        }
        self.catalog_path = self.media_root / "catalog.json"
        self.catalog_path.write_text(json.dumps(self.catalog), encoding="utf-8")
        build_catalog_index(
            self.index_path,
            self.catalog_path,
            self.catalog,
            gallery_cache_root=self.gallery_root,
        )
        self.user = get_user_model().objects.create_user(username="member-fast")
        self.client = Client()
        self.client.force_login(self.user)

    def test_runtime_endpoints_serve_from_sqlite_without_parsing_catalog_json(self):
        self.assertFalse(settings.SESSION_SAVE_EVERY_REQUEST)
        with override_settings(
            SPCBOY_MEDIA_ROOT=self.media_root,
            SPCBOY_GALLERY_CACHE_ROOT=self.gallery_root,
            SPCBOY_SEARCH_INDEX_PATH=self.index_path,
        ), patch("accounts.views._spcboy_catalog_data", side_effect=AssertionError("Must not load catalog.json")):
            res = self.client.get("/spcboy/catalog.json")
            self.assertEqual(res.status_code, 200)
            self.assertIn("ETag", res)
            payload = res.json()
            self.assertEqual(len(payload["consoles"]), 1)
            self.assertEqual(payload["consoles"][0]["games"][0]["albumId"], self.album_id)
            self.assertEqual(payload["consoles"][0]["games"][0]["trackCount"], 2)

            res_304 = self.client.get("/spcboy/catalog.json", HTTP_IF_NONE_MATCH=res["ETag"])
            self.assertEqual(res_304.status_code, 304)

            album_res = self.client.get(f"/spcboy/album/{self.album_id}.json")
            self.assertEqual(album_res.status_code, 200)
            self.assertEqual([t["id"] for t in album_res.json()["tracks"]], ["ct-1", "ct-2"])

            detail_res = self.client.get("/spcboy/track/ct-2.json")
            self.assertEqual(detail_res.status_code, 200)
            self.assertEqual(detail_res.json()["track"]["artist"], "Yasunori Mitsuda")

            nav_res = self.client.get("/spcboy/navigation.json?trackId=ct-1&step=1")
            self.assertEqual(nav_res.status_code, 200)
            self.assertEqual(nav_res.json()["track"]["id"], "ct-2")

            search_res = self.client.get("/spcboy/search.json?q=Presentiment")
            self.assertEqual(search_res.status_code, 200)
            self.assertEqual(search_res.json()["results"][0]["id"], "ct-1")

            fav_add = self.client.post(
                "/spcboy/favorites.json",
                json.dumps({"albumId": self.album_id, "favorite": True}),
                content_type="application/json",
            )
            self.assertEqual(fav_add.status_code, 200)

            fav_pl = self.client.get("/spcboy/favorites/playlist.json")
            self.assertEqual(fav_pl.status_code, 200)
            self.assertEqual([t["id"] for t in fav_pl.json()["tracks"]], ["ct-1", "ct-2"])

            fav_split = self.client.post(
                "/spcboy/favorites.json",
                json.dumps({"removeTrackIds": ["ct-1"]}),
                content_type="application/json",
            )
            self.assertEqual(fav_split.status_code, 200)
            self.assertEqual(list(FavoriteAlbum.objects.filter(user=self.user)), [])
            self.assertEqual(
                list(FavoriteTrack.objects.filter(user=self.user).values_list("track_id", flat=True)),
                ["ct-2"],
            )

            SPCBOYPlaybackHistory.objects.create(
                user=self.user,
                playback_id=uuid.uuid4(),
                title="Presentiment",
                game="Chrono Trigger",
                console="Super Nintendo",
                track_id="ct-1",
            )
            recents_res = self.client.get("/spcboy/recents.json")
            self.assertEqual(recents_res.status_code, 200)
            self.assertTrue(recents_res.json()["results"][0]["available"])
            self.assertEqual(recents_res.json()["results"][0]["artist"], "Yasunori Mitsuda")

            audio_source = get_track_audio_source(self.index_path, "ct-1")
            self.assertEqual(audio_source["archive"], "snes/ct.7z")
            self.assertEqual(audio_source["member"], "01 Presentiment.spc")
