"""Opaque album identity helper and retired gallery compatibility stubs."""
import hashlib
import unicodedata

GALLERY_CACHE_SCHEMA = 6
THUMBNAIL_EXTENSION = ".webp"
THUMBNAIL_MIME_TYPE = "image/webp"


def spcboy_album_id(console, game):
    """Return a stable, opaque identity for a console/game album."""
    console_name = " ".join(unicodedata.normalize("NFC", str(console or "")).split())
    if console_name.casefold() in {"arcade (mixed)", "arcade (capcom)"}:
        # Preserve album-favorite IDs created while all arcade games shared
        # the original Arcade console label.
        console_name = "Arcade"
    identity = "\0".join(
        " ".join(unicodedata.normalize("NFC", str(value or "")).split()).casefold()
        for value in (console_name, game)
    )
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()[:32]


def catalog_albums(catalog):
    return []


def read_gallery_index(cache_root=None):
    return {}
