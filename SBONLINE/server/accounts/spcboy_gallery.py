import hashlib
import json
import os
import subprocess
import tarfile
import tempfile
import unicodedata
import warnings
from io import BytesIO
from pathlib import Path, PurePosixPath

from PIL import Image, ImageOps


GALLERY_CACHE_SCHEMA = 6
THUMBNAIL_SIZE = 240
DETAIL_IMAGE_SIZE = 1200
THUMBNAIL_FORMAT = "WEBP"
THUMBNAIL_EXTENSION = ".webp"
THUMBNAIL_MIME_TYPE = "image/webp"
MAX_ARTWORK_BYTES = 16 * 1024 * 1024
MAX_ARTWORK_PIXELS = 20_000_000


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
    """Group the published track catalog by its console and game identity."""
    if not isinstance(catalog, dict):
        return []
    metadata_by_id = catalog.get("tracks")
    if not isinstance(metadata_by_id, dict):
        return []

    albums = {}
    for console in catalog.get("consoles", []):
        if not isinstance(console, dict):
            continue
        console_name = str(console.get("name", "")).strip()
        for game in console.get("games", []):
            if not isinstance(game, dict):
                continue
            game_name = str(game.get("name", "")).strip()
            album_id = spcboy_album_id(console_name, game_name)
            album = albums.setdefault(album_id, {
                "id": album_id,
                "name": game_name,
                "console": console_name,
                "tracks": [],
                "archives": [],
            })
            for track in game.get("tracks", []):
                if not isinstance(track, dict) or not track.get("id"):
                    continue
                track_id = str(track["id"])
                metadata = metadata_by_id.get(track_id, {})
                if not isinstance(metadata, dict):
                    metadata = {}
                album["tracks"].append({
                    **metadata,
                    **track,
                    "id": track_id,
                    "game": game_name,
                    "console": console_name,
                    "albumId": album_id,
                })
                archive_name = metadata.get("archive")
                if isinstance(archive_name, str) and archive_name not in album["archives"]:
                    album["archives"].append(archive_name)
    return list(albums.values())


def read_gallery_index(cache_root):
    index_path = Path(cache_root) / "index.json"
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError):
        return {}
    if not isinstance(index, dict) or index.get("schemaVersion") != GALLERY_CACHE_SCHEMA:
        return {}
    albums = index.get("albums")
    if not isinstance(albums, dict):
        return {}
    return {
        album_id: record
        for album_id, record in albums.items()
        if isinstance(album_id, str)
        and len(album_id) == 32
        and isinstance(record, dict)
        and record.get("file") == f"{album_id}{THUMBNAIL_EXTENSION}"
        and record.get("detailFile") == f"{album_id}-detail{THUMBNAIL_EXTENSION}"
    }


def _safe_uac_path(media_root, archive_name):
    if not isinstance(archive_name, str):
        return None
    relative = Path(archive_name)
    root = Path(media_root).resolve()
    if relative.is_absolute() or ".." in relative.parts or relative.suffix.casefold() != ".uac":
        return None
    path = (root / relative).resolve()
    if root not in path.parents or not path.is_file():
        return None
    return path


def _webp_renditions(png_bytes):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(png_bytes)) as source:
                if source.format != "PNG" or source.width * source.height > MAX_ARTWORK_PIXELS:
                    return None
                source.load()
                source = ImageOps.exif_transpose(source).convert("RGBA")
                palette_art = source.getcolors(257) is not None
        background = Image.new("RGBA", source.size, (17, 20, 23, 255))
        background.alpha_composite(source)
        rgb = background.convert("RGB")
        del source, background

        def encode(max_size):
            image = rgb.copy()
            # Resize preserves aspect ratio and never enlarges a source.
            image.thumbnail(
                (max_size, max_size),
                resample=Image.Resampling.NEAREST if palette_art else Image.Resampling.LANCZOS,
            )
            result = BytesIO()
            if palette_art:
                image.save(result, format="WEBP", lossless=True, method=6)
            else:
                image.save(result, format="WEBP", quality=90, method=6)
            return result.getvalue()

        return encode(THUMBNAIL_SIZE), encode(DETAIL_IMAGE_SIZE)
    except (Image.DecompressionBombError, Image.DecompressionBombWarning, OSError, ValueError):
        return None, None


def _webp_thumbnail(png_bytes):
    return _webp_renditions(png_bytes)[0]


def _first_png_renditions(archive_path, zstd_path):
    """Read the first in-archive PNG without creating an extracted member tree."""
    process = subprocess.Popen(
        [str(zstd_path), "-d", "-q", "-c", "--", str(archive_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=0,
    )
    try:
        with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
            for member in archive:
                if not member.isfile() or PurePosixPath(member.name).suffix.casefold() != ".png":
                    continue
                if member.size <= 0 or member.size > MAX_ARTWORK_BYTES:
                    continue
                source = archive.extractfile(member)
                if source is None:
                    continue
                with source:
                    image_bytes = source.read(MAX_ARTWORK_BYTES + 1)
                if len(image_bytes) != member.size:
                    continue
                thumbnail, detail_image = _webp_renditions(image_bytes)
                if thumbnail and detail_image:
                    return thumbnail, detail_image, len(image_bytes)
    finally:
        if process.stdout is not None:
            process.stdout.close()
        if process.poll() is None:
            process.kill()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    return None, None, 0


def _sidecar_artwork_sources(media_root, archive_name):
    """Return safe loose PNG sidecars stored beside the UAC."""
    if not isinstance(archive_name, str):
        return []
    relative = Path(archive_name)
    if relative.is_absolute() or ".." in relative.parts or relative.suffix.casefold() != ".uac":
        return []

    sources = []
    seen = set()
    resolved_root = Path(media_root).resolve()
    archive_sidecar = resolved_root / relative
    candidates = (Path(f"{archive_sidecar}.png"), archive_sidecar.with_suffix(".png"))
    for candidate in candidates:
        try:
            path = candidate.resolve()
            if resolved_root not in path.parents or not path.is_file() or path in seen:
                continue
            seen.add(path)
            sources.append((path.relative_to(resolved_root).as_posix(), path))
        except OSError:
            continue
    return sources


def _sidecar_renditions(path):
    try:
        with Path(path).open("rb") as source:
            image_bytes = source.read(MAX_ARTWORK_BYTES + 1)
    except OSError:
        return None, None, 0
    if not image_bytes or len(image_bytes) > MAX_ARTWORK_BYTES:
        return None, None, 0
    thumbnail, detail_image = _webp_renditions(image_bytes)
    return (thumbnail, detail_image, len(image_bytes)) if thumbnail and detail_image else (None, None, 0)


def _atomic_write(path, content):
    path = Path(path)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary_name, 0o640)
        os.replace(temporary_name, path)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass


def build_gallery_cache(catalog, media_root, cache_root, zstd_path):
    """Build private tile and detail WebP caches from UAC images and PNG sidecars."""
    media_root = Path(media_root).resolve()
    cache_root = Path(cache_root)
    cache_root.mkdir(parents=True, exist_ok=True)
    previous = read_gallery_index(cache_root)
    albums = catalog_albums(catalog)
    cached_albums = {}
    archive_results = {}
    counted_archives = set()
    source_bytes = 0
    source_image_bytes = 0
    thumbnail_bytes = 0
    detail_bytes = 0
    failed_archives = 0

    for album in albums:
        for archive_name in album["archives"]:
            archive_path = _safe_uac_path(media_root, archive_name)
            if archive_path is None:
                continue
            try:
                stat = archive_path.stat()
            except OSError:
                continue
            cached = previous.get(album["id"])
            thumb_path = cache_root / f"{album['id']}{THUMBNAIL_EXTENSION}"
            detail_path = cache_root / f"{album['id']}-detail{THUMBNAIL_EXTENSION}"
            archive_is_unchanged = (
                cached
                and cached.get("archive") == archive_name
                and cached.get("archiveBytes") == stat.st_size
                and cached.get("archiveMtimeNs") == stat.st_mtime_ns
                and thumb_path.is_file()
                and detail_path.is_file()
            )
            sidecars = _sidecar_artwork_sources(media_root, archive_name)
            cached_sidecar_is_unchanged = False
            cached_source_type = cached.get("sourceType", "archive") if cached else None
            if archive_is_unchanged and cached_source_type == "sidecar":
                for source_name, source_path in sidecars:
                    try:
                        sidecar_stat = source_path.stat()
                    except OSError:
                        continue
                    if (
                        cached.get("source") == source_name
                        and cached.get("sourceBytes") == sidecar_stat.st_size
                        and cached.get("sourceMtimeNs") == sidecar_stat.st_mtime_ns
                    ):
                        cached_sidecar_is_unchanged = True
                        break
            if archive_is_unchanged and (
                cached_source_type == "archive" or cached_sidecar_is_unchanged
            ):
                record = cached
            else:
                cache_key = (str(archive_path), stat.st_size, stat.st_mtime_ns)
                if cache_key not in archive_results:
                    try:
                        result = _first_png_renditions(archive_path, zstd_path)
                    except (OSError, tarfile.TarError, subprocess.SubprocessError, EOFError):
                        result = (None, None, 0)
                        failed_archives += 1
                    archive_results[cache_key] = result
                thumbnail, detail_image, original_image_bytes = archive_results[cache_key]
                source_type = "archive"
                source_name = archive_name
                sidecar_source_bytes = 0
                source_mtime_ns = 0
                if not thumbnail:
                    source_type = "sidecar"
                    for sidecar_name, sidecar_path in sidecars:
                        try:
                            sidecar_stat = sidecar_path.stat()
                        except OSError:
                            continue
                        thumbnail, detail_image, original_image_bytes = _sidecar_renditions(sidecar_path)
                        if thumbnail and detail_image:
                            source_name = sidecar_name
                            sidecar_source_bytes = sidecar_stat.st_size
                            source_mtime_ns = sidecar_stat.st_mtime_ns
                            break
                if not thumbnail:
                    continue
                _atomic_write(thumb_path, thumbnail)
                _atomic_write(detail_path, detail_image)
                record = {
                    "file": thumb_path.name,
                    "detailFile": detail_path.name,
                    "archive": archive_name,
                    "archiveBytes": stat.st_size,
                    "archiveMtimeNs": stat.st_mtime_ns,
                    "sourceType": source_type,
                    "source": source_name,
                    "sourceBytes": sidecar_source_bytes,
                    "sourceMtimeNs": source_mtime_ns,
                    "sourceImageBytes": original_image_bytes,
                    "thumbnailBytes": len(thumbnail),
                    "thumbnailSha256": hashlib.sha256(thumbnail).hexdigest(),
                    "detailBytes": len(detail_image),
                    "detailSha256": hashlib.sha256(detail_image).hexdigest(),
                }
            cached_albums[album["id"]] = record
            if archive_name not in counted_archives:
                source_bytes += record.get("archiveBytes", 0)
                counted_archives.add(archive_name)
            source_image_bytes += record.get("sourceImageBytes", 0)
            thumbnail_bytes += record.get("thumbnailBytes", 0)
            detail_bytes += record.get("detailBytes", 0)
            break

    index = json.dumps({
        "schemaVersion": GALLERY_CACHE_SCHEMA,
        "thumbnailSize": THUMBNAIL_SIZE,
        "detailImageSize": DETAIL_IMAGE_SIZE,
        "thumbnailFormat": THUMBNAIL_FORMAT,
        "albums": cached_albums,
    }, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"
    _atomic_write(cache_root / "index.json", index)

    retained_files = {
        filename
        for record in cached_albums.values()
        for filename in (record["file"], record["detailFile"])
    }
    retained_files.add("index.json")
    for path in cache_root.iterdir():
        if path.is_file() and path.name not in retained_files and path.suffix.casefold() in {".jpg", ".jpeg", ".png", ".webp"}:
            path.unlink(missing_ok=True)

    return {
        "albums": len(albums),
        "with_artwork": len(cached_albums),
        "source_bytes": source_bytes,
        "source_image_bytes": source_image_bytes,
        "thumbnail_bytes": thumbnail_bytes,
        "detail_bytes": detail_bytes,
        "failed_archives": failed_archives,
    }
