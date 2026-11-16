"""Catalog projections, metadata indexes and artwork links for SPCBOY."""

import json
from functools import lru_cache

from django.conf import settings
from django.urls import reverse

from .models import FavoriteAlbum
from .spcboy_gallery import THUMBNAIL_EXTENSION, read_gallery_index, spcboy_album_id
from .spcboy_timing import catalog_duration_seconds


def spcboy_catalog_data():
    catalog_path = settings.SPCBOY_MEDIA_ROOT / "catalog.json"
    try:
        source_stat = catalog_path.stat()
    except OSError:
        return None
    return _read_spcboy_catalog(source_stat.st_size, source_stat.st_mtime_ns)


@lru_cache(maxsize=2)
def _read_spcboy_catalog(source_size, source_mtime_ns):
    catalog_path = settings.SPCBOY_MEDIA_ROOT / "catalog.json"
    try:
        with catalog_path.open("r", encoding="utf-8") as catalog_file:
            catalog = json.load(catalog_file)
    except (OSError, ValueError):
        return None
    try:
        source_stat = catalog_path.stat()
    except OSError:
        return None
    if (source_stat.st_size, source_stat.st_mtime_ns) != (source_size, source_mtime_ns):
        return spcboy_catalog_data()
    if (
        not isinstance(catalog, dict)
        or not isinstance(catalog.get("consoles"), list)
        or not isinstance(catalog.get("tracks"), dict)
    ):
        return None
    return catalog


def spcboy_gallery_index():
    index_path = settings.SPCBOY_GALLERY_CACHE_ROOT / "index.json"
    try:
        source_stat = index_path.stat()
    except OSError:
        return {}
    return _read_spcboy_gallery_index(source_stat.st_size, source_stat.st_mtime_ns)


def spcboy_artwork_url(album_id, artwork_index=None, *, detail=False):
    artwork_index = spcboy_gallery_index() if artwork_index is None else artwork_index
    artwork = artwork_index.get(album_id) if isinstance(artwork_index, dict) else None
    filename_key = "detailFile" if detail else "file"
    expected_file = f"{album_id}-detail{THUMBNAIL_EXTENSION}" if detail else f"{album_id}{THUMBNAIL_EXTENSION}"
    if not isinstance(artwork, dict) or artwork.get(filename_key) != expected_file:
        return ""
    image_path = settings.SPCBOY_GALLERY_CACHE_ROOT / expected_file
    if not image_path.is_file():
        return ""
    hash_key = "detailSha256" if detail else "thumbnailSha256"
    version = str(artwork.get(hash_key, ""))[:12]
    size = "&size=detail" if detail else ""
    return f"{reverse('spcboy_artwork', args=[album_id])}?v={version}{size}"


def track_artwork_url(track, artwork_index=None):
    if not isinstance(track, dict):
        return ""
    return spcboy_artwork_url(
        spcboy_album_id(track.get("console"), track.get("game")),
        artwork_index,
    )


def attach_track_artwork(track, artwork_index, album_artwork_urls):
    track = dict(track)
    album_id = spcboy_album_id(track.get("console"), track.get("game"))
    if album_id not in album_artwork_urls:
        album_artwork_urls[album_id] = spcboy_artwork_url(album_id, artwork_index)
    track["artwork_url"] = album_artwork_urls[album_id]
    return track


@lru_cache(maxsize=2)
def _read_spcboy_gallery_index(source_size, source_mtime_ns):
    return read_gallery_index(settings.SPCBOY_GALLERY_CACHE_ROOT)


def public_spcboy_track(track, metadata, game, console):
    """Public display metadata only; source/archive identity stays server-side."""
    metadata = metadata if isinstance(metadata, dict) else {}
    album_id = spcboy_album_id(console, game)
    return {
        "id": str(track["id"]),
        "title": str(track.get("title") or metadata.get("title") or ""),
        "artist": str(metadata.get("artist") or track.get("artist") or ""),
        "year": str(metadata.get("year") or track.get("year") or ""),
        "dumper": str(metadata.get("dumper") or track.get("dumper") or ""),
        "durationSeconds": catalog_duration_seconds(track, metadata),
        "game": str(game),
        "console": str(console),
        "albumPlaylistUrl": reverse("spcboy_album_playlist", args=[album_id]),
    }


def _build_catalog_track_index(catalog):
    if not catalog:
        return {}
    return {
        str(track["id"]): public_spcboy_track(
            track, catalog["tracks"].get(str(track["id"])),
            game.get("name", ""), console.get("name", ""),
        )
        for console in catalog["consoles"]
        for game in console.get("games", [])
        for track in game.get("tracks", [])
        if isinstance(track, dict) and track.get("id")
    }


@lru_cache(maxsize=2)
def _cached_spcboy_track_index(source_size, source_mtime_ns):
    return _build_catalog_track_index(_read_spcboy_catalog(source_size, source_mtime_ns))


def catalog_track_index(catalog):
    if not catalog:
        return {}
    try:
        source_stat = (settings.SPCBOY_MEDIA_ROOT / "catalog.json").stat()
    except OSError:
        return _build_catalog_track_index(catalog)
    if catalog is _read_spcboy_catalog(source_stat.st_size, source_stat.st_mtime_ns):
        return _cached_spcboy_track_index(source_stat.st_size, source_stat.st_mtime_ns)
    return _build_catalog_track_index(catalog)


def _build_catalog_album_index(catalog):
    if not isinstance(catalog, dict):
        return {}
    albums = {}
    for console in catalog.get("consoles", []):
        if not isinstance(console, dict):
            continue
        console_name = str(console.get("name", "")).strip()
        for game in console.get("games", []):
            if not isinstance(game, dict):
                continue
            game_name = str(game.get("name", "")).strip()
            track_count = sum(
                1 for item in game.get("tracks", [])
                if isinstance(item, dict) and item.get("id")
            )
            if not track_count:
                continue
            album_id = spcboy_album_id(console_name, game_name)
            albums[album_id] = {
                "id": album_id,
                "name": game_name,
                "console": console_name,
                "track_count": track_count,
            }
    return albums


@lru_cache(maxsize=2)
def _cached_spcboy_album_index(source_size, source_mtime_ns):
    return _build_catalog_album_index(_read_spcboy_catalog(source_size, source_mtime_ns))


def catalog_album_index(catalog):
    if not isinstance(catalog, dict):
        return {}
    try:
        source_stat = (settings.SPCBOY_MEDIA_ROOT / "catalog.json").stat()
    except OSError:
        return _build_catalog_album_index(catalog)
    if catalog is _read_spcboy_catalog(source_stat.st_size, source_stat.st_mtime_ns):
        return _cached_spcboy_album_index(source_stat.st_size, source_stat.st_mtime_ns)
    return _build_catalog_album_index(catalog)


def favorite_album_rows(user, catalog):
    albums = catalog_album_index(catalog)
    return [
        {
            **albums[favorite.album_id],
            "added_at": favorite.added_at,
            "play_url": reverse("spcboy_album_playlist", args=[favorite.album_id]),
        }
        for favorite in FavoriteAlbum.objects.filter(user=user).order_by("-added_at", "pk")
        if favorite.album_id in albums
    ]
