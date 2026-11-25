import hashlib
import json
import os
import re
import sqlite3
import tempfile
import threading
import unicodedata
from pathlib import Path

from .spcboy_gallery import THUMBNAIL_EXTENSION, read_gallery_index, spcboy_album_id
from .spcboy_timing import catalog_duration_seconds

_INDEX_LOCK = threading.Lock()
_TOKEN_PATTERN = re.compile(r"[^\W_]+", re.UNICODE)
_INDEX_VERSION = 5


def _url_prefixes():
    try:
        from django.urls import reverse
        dummy_id = "0" * 32
        album_sample = reverse("spcboy_album_playlist", args=[dummy_id])
        artwork_sample = reverse("spcboy_artwork", args=[dummy_id])
        return album_sample.split(dummy_id), artwork_sample.split(dummy_id)
    except Exception:
        return ["/spcboy/album/", ".json"], ["/spcboy/artwork/", ".webp"]


def _album_playlist_url(album_parts, album_id):
    return f"{album_parts[0]}{album_id}{album_parts[1]}"


def _artwork_urls(artwork_parts, album_id, artwork_record, existing_files):
    return "", 


def normalize_search_text(value):
    decomposed = unicodedata.normalize("NFKD", str(value or "").casefold())
    return "".join(character for character in decomposed if not unicodedata.combining(character))


def search_terms(value):
    return _TOKEN_PATTERN.findall(normalize_search_text(value))


def _gallery_stat(gallery_cache_root=None):
    return 0, 0


def _scan_gallery(gallery_cache_root=None):
    return {}, set()


def _default_gallery_root():
    try:
        from django.conf import settings
        return getattr(settings, "SPCBOY_GALLERY_CACHE_ROOT", None)
    except Exception:
        return None


def _row_to_public_track(row, album_parts):
    return {
        "id": row["id"],
        "title": row["title"],
        "artist": row["artist"],
        "year": row["year"],
        "dumper": row["dumper"],
        "durationSeconds": row["duration_seconds"],
        "game": row["game"],
        "console": row["console"],
        "albumPlaylistUrl": _album_playlist_url(album_parts, row["album_id"]),
    }


def _collect_catalog_data(catalog, gallery_cache_root=None):
    album_parts, artwork_parts = _url_prefixes()
    artwork_index, existing_files = _scan_gallery(gallery_cache_root)
    metadata_by_id = catalog["tracks"]
    seen_ids = set()
    order = 0
    consoles_manifest = []
    albums_rows = {}
    track_rows = []

    for console in catalog["consoles"]:
        if not isinstance(console, dict):
            continue
        console_name = str(console.get("name", ""))
        games_manifest = []
        for game in console.get("games", []):
            if not isinstance(game, dict):
                continue
            game_name = str(game.get("name", ""))
            album_id = spcboy_album_id(console_name, game_name)
            thumb_url, detail_url = _artwork_urls(
                artwork_parts, album_id, artwork_index.get(album_id), existing_files,
            )
            valid_tracks = [
                track for track in game.get("tracks", [])
                if isinstance(track, dict) and track.get("id")
            ]
            track_count = len(valid_tracks)
            games_manifest.append({
                "name": game_name,
                "albumId": album_id,
                "artworkUrl": thumb_url,
                "detailArtworkUrl": detail_url,
                "trackCount": track_count,
            })
            if album_id not in albums_rows:
                albums_rows[album_id] = (
                    album_id, console_name.strip(), game_name.strip(),
                    track_count, order + 1, thumb_url, detail_url,
                )
            for track in valid_tracks:
                track_id = str(track["id"])
                if track_id in seen_ids:
                    continue
                metadata = metadata_by_id.get(track_id, {})
                if not isinstance(metadata, dict):
                    continue
                title = str(track.get("title") or metadata.get("title") or "")
                artist = str(metadata.get("artist") or track.get("artist") or "")
                year = str(metadata.get("year") or track.get("year") or "")
                dumper = str(metadata.get("dumper") or track.get("dumper") or "")
                archive = str(metadata.get("archive") or "")
                member = str(metadata.get("member") or "")
                try:
                    track_index = int(metadata.get("trackIndex", 0) or 0)
                except (TypeError, ValueError):
                    track_index = 0
                try:
                    play_ms = int(metadata.get("playMilliseconds", 0) or 0)
                except (TypeError, ValueError):
                    play_ms = 0
                try:
                    fade_ms = int(metadata.get("fadeMilliseconds", 0) or 0)
                except (TypeError, ValueError):
                    fade_ms = 0
                try:
                    duration = float(catalog_duration_seconds(track, metadata))
                except (TypeError, ValueError):
                    duration = 0.0
                search_text = normalize_search_text(" ".join((title, artist, game_name, console_name)))
                seen_ids.add(track_id)
                order += 1
                track_rows.append((
                    track_id, album_id, title, artist, year, dumper, game_name,
                    console_name, duration, order, search_text,
                    archive, member, track_index, play_ms, fade_ms,
                ))
        consoles_manifest.append({"name": console_name, "games": games_manifest})

    payload_bytes = json.dumps(
        {"consoles": consoles_manifest}, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    etag = f'"{hashlib.sha256(payload_bytes).hexdigest()[:24]}"'
    return list(albums_rows.values()), track_rows, etag, payload_bytes


def _index_is_current(index_path, source_stat, gallery_size=0, gallery_mtime_ns=0):
    if not index_path.is_file():
        return False
    try:
        with sqlite3.connect(f"file:{index_path}?mode=ro", uri=True, timeout=5) as connection:
            row = connection.execute(
                "SELECT source_size, source_mtime_ns, index_version "
                "FROM catalog_state WHERE singleton = 1"
            ).fetchone()
            return row == (source_stat.st_size, source_stat.st_mtime_ns, _INDEX_VERSION)
    except sqlite3.Error:
        return False


def catalog_index_is_current(index_path, source_path, *, gallery_cache_root=None):
    try:
        source_stat = Path(source_path).stat()
    except OSError:
        return False
    gallery_root = _default_gallery_root() if gallery_cache_root is None else gallery_cache_root
    gallery_size, gallery_mtime_ns = _gallery_stat(gallery_root)
    return _index_is_current(Path(index_path), source_stat, gallery_size, gallery_mtime_ns)


def build_catalog_index(index_path, source_path, catalog, *, gallery_cache_root=None):
    index_path = Path(index_path)
    source_path = Path(source_path)
    gallery_root = _default_gallery_root() if gallery_cache_root is None else gallery_cache_root
    gallery_size, gallery_mtime_ns = _gallery_stat(gallery_root)
    with _INDEX_LOCK:
        source_stat = source_path.stat()
        if _index_is_current(index_path, source_stat, gallery_size, gallery_mtime_ns):
            return False
        albums_rows, track_rows, etag, payload_bytes = _collect_catalog_data(catalog, gallery_root)
        index_path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{index_path.name}.", suffix=".tmp", dir=index_path.parent,
        )
        os.close(descriptor)
        temporary_path = Path(temporary_name)
        try:
            with sqlite3.connect(temporary_path, timeout=20) as connection:
                connection.execute("PRAGMA journal_mode=DELETE")
                connection.execute("PRAGMA synchronous=FULL")
                connection.execute(
                    "CREATE TABLE catalog_albums ("
                    "album_id TEXT PRIMARY KEY, console_name TEXT NOT NULL, name TEXT NOT NULL, "
                    "track_count INTEGER NOT NULL, source_order INTEGER NOT NULL, "
                    "artwork_url TEXT NOT NULL, detail_artwork_url TEXT NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE catalog_tracks ("
                    "id TEXT NOT NULL UNIQUE, album_id TEXT NOT NULL, "
                    "title TEXT NOT NULL, artist TEXT NOT NULL, year TEXT NOT NULL, dumper TEXT NOT NULL, "
                    "game TEXT NOT NULL, console TEXT NOT NULL, duration_seconds REAL NOT NULL, "
                    "source_order INTEGER NOT NULL, search_text TEXT NOT NULL, "
                    "archive TEXT NOT NULL, member TEXT NOT NULL, track_index INTEGER NOT NULL, "
                    "play_ms INTEGER NOT NULL, fade_ms INTEGER NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE catalog_manifest ("
                    "singleton INTEGER PRIMARY KEY CHECK (singleton = 1), "
                    "etag TEXT NOT NULL, payload_json BLOB NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE catalog_state ("
                    "singleton INTEGER PRIMARY KEY CHECK (singleton = 1), "
                    "source_size INTEGER NOT NULL, source_mtime_ns INTEGER NOT NULL, "
                    "gallery_size INTEGER NOT NULL, gallery_mtime_ns INTEGER NOT NULL, "
                    "track_count INTEGER NOT NULL, index_version INTEGER NOT NULL)"
                )
                connection.executemany(
                    "INSERT INTO catalog_albums "
                    "(album_id, console_name, name, track_count, source_order, artwork_url, detail_artwork_url) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    albums_rows,
                )
                connection.executemany(
                    "INSERT INTO catalog_tracks "
                    "(id, album_id, title, artist, year, dumper, game, console, duration_seconds, "
                    "source_order, search_text, archive, member, track_index, play_ms, fade_ms) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    track_rows,
                )
                connection.execute(
                    "CREATE INDEX idx_catalog_tracks_album_order ON catalog_tracks(album_id, source_order)"
                )
                connection.execute(
                    "CREATE INDEX idx_catalog_tracks_source_order ON catalog_tracks(source_order)"
                )
                track_count = len(track_rows)
                connection.execute(
                    "CREATE VIRTUAL TABLE catalog_tracks_fts USING fts5("
                    "search_text, content='catalog_tracks', content_rowid='rowid', tokenize='trigram')"
                )
                connection.execute("INSERT INTO catalog_tracks_fts(catalog_tracks_fts) VALUES ('rebuild')")
                connection.execute(
                    "INSERT INTO catalog_manifest (singleton, etag, payload_json) VALUES (1, ?, ?)",
                    (etag, payload_bytes),
                )
                connection.execute(
                    "INSERT INTO catalog_state "
                    "(singleton, source_size, source_mtime_ns, gallery_size, gallery_mtime_ns, track_count, index_version) "
                    "VALUES (1, ?, ?, ?, ?, ?, ?)",
                    (
                        source_stat.st_size, source_stat.st_mtime_ns,
                        gallery_size, gallery_mtime_ns, track_count, _INDEX_VERSION,
                    ),
                )
                connection.commit()
            os.chmod(temporary_path, 0o600)
            if source_path.stat().st_mtime_ns != source_stat.st_mtime_ns or source_path.stat().st_size != source_stat.st_size:
                raise RuntimeError("The hosted music catalog changed during search-index creation.")
            os.replace(temporary_path, index_path)
        finally:
            temporary_path.unlink(missing_ok=True)
    return True


def ensure_catalog_store(index_path, source_path, catalog_loader, *, gallery_cache_root=None):
    """Ensure the SQLite catalog store matches catalog.json without loading JSON on warm reads."""
    gallery_root = _default_gallery_root() if gallery_cache_root is None else gallery_cache_root
    if catalog_index_is_current(index_path, source_path, gallery_cache_root=gallery_root):
        return True
    catalog = catalog_loader()
    if catalog is None:
        return False
    build_catalog_index(index_path, source_path, catalog, gallery_cache_root=gallery_root)
    return True


def _connect_ro(index_path):
    connection = sqlite3.connect(f"file:{Path(index_path)}?mode=ro", uri=True, timeout=10)
    connection.row_factory = sqlite3.Row
    return connection


def read_catalog_manifest(index_path):
    with _connect_ro(index_path) as connection:
        row = connection.execute(
            "SELECT etag, payload_json FROM catalog_manifest WHERE singleton = 1"
        ).fetchone()
    if row is None:
        return None, None
    return row["etag"], bytes(row["payload_json"])


def get_album_playlist(index_path, album_id):
    album_parts, _ = _url_prefixes()
    with _connect_ro(index_path) as connection:
        album = connection.execute(
            "SELECT album_id, console_name, name FROM catalog_albums WHERE album_id = ?",
            (album_id,),
        ).fetchone()
        if album is None:
            return None
        rows = connection.execute(
            "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds "
            "FROM catalog_tracks WHERE album_id = ? ORDER BY source_order",
            (album_id,),
        ).fetchall()
    if not rows:
        return None
    return {
        "albumId": album_id,
        "name": album["name"],
        "console": album["console_name"],
        "tracks": [_row_to_public_track(row, album_parts) for row in rows],
    }


def get_tracks_by_ids(index_path, track_ids):
    unique_ids = [tid for tid in dict.fromkeys(str(t) for t in track_ids if t)]
    if not unique_ids:
        return {}
    album_parts, _ = _url_prefixes()
    results = {}
    with _connect_ro(index_path) as connection:
        for offset in range(0, len(unique_ids), 500):
            batch = unique_ids[offset:offset + 500]
            placeholders = ",".join("?" for _ in batch)
            rows = connection.execute(
                "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds "
                f"FROM catalog_tracks WHERE id IN ({placeholders})",
                batch,
            ).fetchall()
            for row in rows:
                results[row["id"]] = _row_to_public_track(row, album_parts)
    return results


def get_albums_by_ids(index_path, album_ids, *, require_tracks=True):
    unique_ids = [aid for aid in dict.fromkeys(str(a) for a in album_ids if a)]
    if not unique_ids:
        return {}
    results = {}
    track_clause = " AND track_count > 0" if require_tracks else ""
    with _connect_ro(index_path) as connection:
        for offset in range(0, len(unique_ids), 500):
            batch = unique_ids[offset:offset + 500]
            placeholders = ",".join("?" for _ in batch)
            rows = connection.execute(
                "SELECT album_id, console_name, name, track_count "
                f"FROM catalog_albums WHERE album_id IN ({placeholders}){track_clause}",
                batch,
            ).fetchall()
            for row in rows:
                results[row["album_id"]] = {
                    "id": row["album_id"],
                    "name": row["name"],
                    "console": row["console_name"],
                    "track_count": row["track_count"],
                }
    return results


def get_album_track_lists_for_tracks(index_path, track_ids):
    """Return {album_id: [ordered_track_ids]} for albums containing any of track_ids."""
    unique_ids = [tid for tid in dict.fromkeys(str(t) for t in track_ids if t)]
    if not unique_ids:
        return {}
    with _connect_ro(index_path) as connection:
        album_ids = set()
        for offset in range(0, len(unique_ids), 500):
            batch = unique_ids[offset:offset + 500]
            placeholders = ",".join("?" for _ in batch)
            rows = connection.execute(
                f"SELECT DISTINCT album_id FROM catalog_tracks WHERE id IN ({placeholders})",
                batch,
            ).fetchall()
            album_ids.update(row["album_id"] for row in rows)
        if not album_ids:
            return {}
        album_list = list(album_ids)
        grouped = {}
        for offset in range(0, len(album_list), 500):
            batch = album_list[offset:offset + 500]
            placeholders = ",".join("?" for _ in batch)
            rows = connection.execute(
                "SELECT album_id, id FROM catalog_tracks "
                f"WHERE album_id IN ({placeholders}) ORDER BY source_order",
                batch,
            ).fetchall()
            for row in rows:
                grouped.setdefault(row["album_id"], []).append(row["id"])
    return grouped


def get_favorite_playlist_page(index_path, track_dates, album_dates, *, page=1, page_size=100):
    if not track_dates and not album_dates:
        return [], None
    album_parts, _ = _url_prefixes()
    clauses = []
    params = []
    if track_dates:
        t_ids = list(track_dates.keys())
        for offset in range(0, len(t_ids), 400):
            batch = t_ids[offset:offset + 400]
            clauses.append(f"id IN ({','.join('?' for _ in batch)})")
            params.extend(batch)
    if album_dates:
        a_ids = list(album_dates.keys())
        for offset in range(0, len(a_ids), 400):
            batch = a_ids[offset:offset + 400]
            clauses.append(f"album_id IN ({','.join('?' for _ in batch)})")
            params.extend(batch)
    where = " OR ".join(clauses)
    with _connect_ro(index_path) as connection:
        rows = connection.execute(
            "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds, source_order "
            f"FROM catalog_tracks WHERE {where} ORDER BY source_order",
            params,
        ).fetchall()
    matching = []
    for row in rows:
        track_added_at = track_dates.get(row["id"])
        album_added_at = album_dates.get(row["album_id"])
        added_at = min(
            (value for value in (track_added_at, album_added_at) if value is not None),
            default=None,
        )
        if added_at is None:
            continue
        item = _row_to_public_track(row, album_parts)
        item["addedAt"] = added_at.isoformat()
        matching.append((added_at, row["source_order"], item))
    matching.sort(key=lambda item: (item[0], item[1]))
    offset = (page - 1) * page_size
    results = [item for _, _, item in matching[offset:offset + page_size]]
    next_page = page + 1 if offset + len(results) < len(matching) else None
    return results, next_page


def get_track_audio_source(index_path, track_id):
    with _connect_ro(index_path) as connection:
        row = connection.execute(
            "SELECT id, title, game, console, archive, member, track_index, play_ms, fade_ms "
            "FROM catalog_tracks WHERE id = ?",
            (track_id,),
        ).fetchone()
    if row is None:
        return None
    return {
        "id": row["id"],
        "title": row["title"],
        "game": row["game"],
        "console": row["console"],
        "archive": row["archive"],
        "member": row["member"],
        "trackIndex": row["track_index"],
        "playMilliseconds": row["play_ms"],
        "fadeMilliseconds": row["fade_ms"],
    }


def query_catalog_index(index_path, query, *, page=1, page_size=100):
    terms = search_terms(query)
    if not terms:
        return {"results": [], "total": 0, "nextPage": None}
    if len(terms) > 20:
        raise ValueError("Search with no more than 20 words at a time.")
    clauses = []
    parameters = []
    long_terms = [term for term in terms if len(term) >= 3]
    short_terms = [term for term in terms if len(term) < 3]
    if long_terms:
        match = " AND ".join(f'"{term}"' for term in long_terms)
        clauses.append("rowid IN (SELECT rowid FROM catalog_tracks_fts WHERE catalog_tracks_fts MATCH ?)")
        parameters.append(match)
    for term in short_terms:
        escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        clauses.append("search_text LIKE ? ESCAPE '\\'")
        parameters.append(f"%{escaped}%")
    where = " AND ".join(clauses)
    offset = (page - 1) * page_size
    album_parts, _ = _url_prefixes()
    with _connect_ro(index_path) as connection:
        total = connection.execute(f"SELECT COUNT(*) FROM catalog_tracks WHERE {where}", parameters).fetchone()[0]
        rows = connection.execute(
            "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds "
            f"FROM catalog_tracks WHERE {where} ORDER BY source_order LIMIT ? OFFSET ?",
            [*parameters, page_size, offset],
        ).fetchall()
    return {
        "results": [_row_to_public_track(row, album_parts) for row in rows],
        "total": total,
        "nextPage": page + 1 if offset + len(rows) < total else None,
    }


def adjacent_catalog_track(index_path, track_id, step):
    """Return the next or previous catalog track without shipping the catalog."""
    direction = 1 if step >= 0 else -1
    operator = ">" if direction > 0 else "<"
    order = "ASC" if direction > 0 else "DESC"
    album_parts, _ = _url_prefixes()
    with _connect_ro(index_path) as connection:
        current = connection.execute(
            "SELECT source_order FROM catalog_tracks WHERE id = ?",
            (track_id,),
        ).fetchone()
        if current is None:
            return None
        row = connection.execute(
            "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds "
            f"FROM catalog_tracks WHERE source_order {operator} ? ORDER BY source_order {order} LIMIT 1",
            (current["source_order"],),
        ).fetchone()
        if row is None:
            wrap_order = "ASC" if direction > 0 else "DESC"
            row = connection.execute(
                "SELECT id, album_id, title, artist, year, dumper, game, console, duration_seconds "
                f"FROM catalog_tracks ORDER BY source_order {wrap_order} LIMIT 1"
            ).fetchone()
    if row is None:
        return None
    return _row_to_public_track(row, album_parts)
