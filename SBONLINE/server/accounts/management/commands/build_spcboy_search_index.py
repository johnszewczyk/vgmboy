from django.conf import settings
from django.core.management.base import BaseCommand

from accounts.catalog_search import build_catalog_index
from accounts.views import _spcboy_catalog_data


class Command(BaseCommand):
    help = "Build or refresh the private search index for hosted SPCBOY tracks."

    def handle(self, *args, **options):
        catalog = _spcboy_catalog_data()
        if catalog is None:
            self.stdout.write("SPCBOY catalog is not installed; its search index will be built when available.")
            return
        source_path = settings.SPCBOY_MEDIA_ROOT / "catalog.json"
        changed = build_catalog_index(settings.SPCBOY_SEARCH_INDEX_PATH, source_path, catalog)
        state = "rebuilt" if changed else "already current"
        self.stdout.write(f"Hosted SPCBOY search index {state}.")
