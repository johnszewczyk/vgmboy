import os
import re
import sqlite3
import tempfile
import threading
import unicodedata
from pathlib import Path

from .spcboy_timing import catalog_duration_seconds

_INDEX_LOCK = threading.Lock()
_TOKEN_PATTERN = re.compile(r"[^\W_]+", re.UNICODE)
_INDEX_VERSION = 2


def normalize_search_text(value):
    decomposed = unicodedata.normalize("NFKD", str(value or "").casefold())
    return "".join(character for character in decomposed if not unicodedata.combining(character))


def search_terms(value):
    return _TOKEN_PATTERN.findall(normalize_search_text(value))


def _catalog_rows(catalog):
    metadata_by_id = catalog["tracks"]
    seen_ids = set()
    order = 0
    for console in catalog["consoles"]:
        console_name = str(console.get("name", ""))
        for game in console.get("games", []):
            game_name = str(game.get("name", ""))
            for track in game.get("tracks", []):
                if not isinstance(track, dict) or not track.get("id"):
                    continue
                track_id = str(track["id"])
                if track_id in seen_ids:
                    continue
                metadata = metadata_by_id.get(track_id, {})
                if not isinstance(metadata, dict):
                    continue
                title = str(track.get("title") or metadata.get("title") or "")
                artist = str(metadata.get("artist") or track.get("artist") or "")
                try:
                    duration = float(catalog_duration_seconds(track, metadata))
                except (TypeError, ValueError):
                    duration = 0
                search_text = normalize_search_text(" ".join((title, artist, game_name, console_name)))
                seen_ids.add(track_id)
                order += 1
                yield track_id, title, artist, game_name, console_name, duration, order, search_text


def _index_is_current(index_path, source_stat):
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


def catalog_index_is_current(index_path, source_path):
    try:
        source_stat = Path(source_path).stat()
    except OSError:
        return False
    return _index_is_current(Path(index_path), source_stat)


def build_catalog_index(index_path, source_path, catalog):
    index_path = Path(index_path)
    source_path = Path(source_path)
    with _INDEX_LOCK:
        source_stat = source_path.stat()
        if _index_is_current(index_path, source_stat):
            return False
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
                    "CREATE TABLE catalog_tracks ("
                    "id TEXT NOT NULL UNIQUE, title TEXT NOT NULL, artist TEXT NOT NULL, "
                    "game TEXT NOT NULL, console TEXT NOT NULL, duration_seconds REAL NOT NULL, "
                    "source_order INTEGER NOT NULL, search_text TEXT NOT NULL)"
                )
                connection.execute(
                    "CREATE TABLE catalog_state ("
                    "singleton INTEGER PRIMARY KEY CHECK (singleton = 1), "
                    "source_size INTEGER NOT NULL, source_mtime_ns INTEGER NOT NULL, "
                    "track_count INTEGER NOT NULL, index_version INTEGER NOT NULL)"
                )
                connection.executemany(
                    "INSERT INTO catalog_tracks "
                    "(id, title, artist, game, console, duration_seconds, source_order, search_text) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    _catalog_rows(catalog),
                )
                track_count = connection.execute("SELECT COUNT(*) FROM catalog_tracks").fetchone()[0]
                connection.execute(
                    "CREATE VIRTUAL TABLE catalog_tracks_fts USING fts5("
                    "search_text, content='catalog_tracks', content_rowid='rowid', tokenize='trigram')"
                )
                connection.execute("INSERT INTO catalog_tracks_fts(catalog_tracks_fts) VALUES ('rebuild')")
                connection.execute(
                    "INSERT INTO catalog_state"
                    "(singleton, source_size, source_mtime_ns, track_count, index_version) "
                    "VALUES (1, ?, ?, ?, ?)",
                    (source_stat.st_size, source_stat.st_mtime_ns, track_count, _INDEX_VERSION),
                )
                connection.commit()
            os.chmod(temporary_path, 0o600)
            if source_path.stat().st_mtime_ns != source_stat.st_mtime_ns or source_path.stat().st_size != source_stat.st_size:
                raise RuntimeError("The hosted music catalog changed during search-index creation.")
            os.replace(temporary_path, index_path)
        finally:
            temporary_path.unlink(missing_ok=True)
    return True


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
    with sqlite3.connect(f"file:{Path(index_path)}?mode=ro", uri=True, timeout=10) as connection:
        connection.row_factory = sqlite3.Row
        total = connection.execute(f"SELECT COUNT(*) FROM catalog_tracks WHERE {where}", parameters).fetchone()[0]
        rows = connection.execute(
            "SELECT id, title, artist, game, console, duration_seconds "
            f"FROM catalog_tracks WHERE {where} ORDER BY source_order LIMIT ? OFFSET ?",
            [*parameters, page_size, offset],
        ).fetchall()
    return {
        "results": [
            {
                "id": row["id"],
                "title": row["title"],
                "artist": row["artist"],
                "game": row["game"],
                "console": row["console"],
                "durationSeconds": row["duration_seconds"],
            }
            for row in rows
        ],
        "total": total,
        "nextPage": page + 1 if offset + len(rows) < total else None,
    }


def adjacent_catalog_track(index_path, track_id, step):
    """Return the next or previous catalog track without shipping the catalog."""
    direction = 1 if step >= 0 else -1
    operator = ">" if direction > 0 else "<"
    order = "ASC" if direction > 0 else "DESC"
    with sqlite3.connect(f"file:{Path(index_path)}?mode=ro", uri=True, timeout=10) as connection:
        connection.row_factory = sqlite3.Row
        current = connection.execute(
            "SELECT source_order FROM catalog_tracks WHERE id = ?",
            (track_id,),
        ).fetchone()
        if current is None:
            return None
        row = connection.execute(
            "SELECT id, title, artist, game, console, duration_seconds "
            f"FROM catalog_tracks WHERE source_order {operator} ? ORDER BY source_order {order} LIMIT 1",
            (current["source_order"],),
        ).fetchone()
        if row is None:
            wrap_order = "ASC" if direction > 0 else "DESC"
            row = connection.execute(
                "SELECT id, title, artist, game, console, duration_seconds "
                f"FROM catalog_tracks ORDER BY source_order {wrap_order} LIMIT 1"
            ).fetchone()
    if row is None:
        return None
    return {
        "id": row["id"],
        "title": row["title"],
        "artist": row["artist"],
        "game": row["game"],
        "console": row["console"],
        "durationSeconds": row["duration_seconds"],
    }
