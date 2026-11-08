from django.conf import settings
from django.core.management.base import BaseCommand

from accounts.spcboy_gallery import build_gallery_cache
from accounts.views import _spcboy_catalog_data


class Command(BaseCommand):
    help = "Build private tile and detail WebP images from SPCBOY UAC and sidecar artwork."

    def handle(self, *args, **options):
        catalog = _spcboy_catalog_data()
        if catalog is None:
            self.stdout.write("SPCBOY catalog is not installed; its gallery cache will be built when available.")
            return
        result = build_gallery_cache(
            catalog,
            settings.SPCBOY_MEDIA_ROOT,
            settings.SPCBOY_GALLERY_CACHE_ROOT,
            settings.SPCBOY_ZSTD,
        )
        self.stdout.write(
            "SPCBOY gallery cache: "
            f"{result['with_artwork']:,}/{result['albums']:,} albums with artwork, "
            f"{result['source_bytes']:,} source-package bytes indexed, "
            f"{result['source_image_bytes']:,} source PNG bytes, "
            f"{result['thumbnail_bytes']:,} thumbnail WebP bytes, "
            f"{result['detail_bytes']:,} detail WebP bytes, "
            f"{result['failed_archives']:,} unreadable UAC packages."
        )
