from io import BytesIO

from django.test import SimpleTestCase
from PIL import Image

from .spcboy_gallery import _webp_thumbnail


class ArtworkSizeTests(SimpleTestCase):
    def test_thumbnail_only_shrinks_without_distorting_aspect(self):
        cases = [
            ((32, 24), (32, 24)),
            ((600, 300), (240, 120)),
            ((128, 128), (128, 128)),
        ]
        for original, expected in cases:
            with self.subTest(original=original):
                source = BytesIO()
                Image.new("RGB", original, "red").save(source, format="PNG")
                with Image.open(BytesIO(_webp_thumbnail(source.getvalue()))) as result:
                    self.assertEqual(result.size, expected)
