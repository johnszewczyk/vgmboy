#!/usr/bin/env python3
"""Create a root-only recovery archive for the private admin service."""

import gzip
import grp
import json
import os
import shutil
import sqlite3
import sys
import tarfile
import tempfile
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path


DATA_DIR = Path("/var/lib/precalc-admin")
DATABASE = DATA_DIR / "db.sqlite3"
MEDIA_DIR = DATA_DIR / "media"
ENV_FILE = Path("/etc/precalc-admin.env")
BACKUP_DIR = Path("/var/backups/precalc-admin")
STATUS_DIR = DATA_DIR / "backup-status"
STATUS_FILE = STATUS_DIR / "status.json"
RETENTION_COUNT = 3
MINIMUM_FREE_BYTES = 64 * 1024 * 1024


def utc_now():
    return datetime.now(timezone.utc)


def utc_stamp(value):
    return value.isoformat().replace("+00:00", "Z")


def _ensure_status_dir():
    group_id = grp.getgrnam("precalc-admin").gr_gid
    STATUS_DIR.mkdir(mode=0o750, parents=True, exist_ok=True)
    os.chown(STATUS_DIR, 0, group_id)
    os.chmod(STATUS_DIR, 0o750)


def _read_status():
    try:
        return json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _write_status(changes):
    _ensure_status_dir()
    status = _read_status()
    status.update(changes)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".status-", dir=STATUS_DIR)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(status, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        group_id = grp.getgrnam("precalc-admin").gr_gid
        os.chown(temporary_name, 0, group_id)
        os.chmod(temporary_name, 0o640)
        os.replace(temporary_name, STATUS_FILE)
        directory_fd = os.open(STATUS_DIR, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass


def _media_size():
    return sum(path.stat().st_size for path in _media_backup_paths() if path.is_file() and not path.is_symlink())


def _media_backup_paths():
    """Keep member data and gallery art; game packages remain in the local source library."""
    paths = {MEDIA_DIR}
    if not MEDIA_DIR.is_dir():
        return []
    for child in MEDIA_DIR.iterdir():
        if child.is_symlink():
            continue
        if child.name != "spcboy":
            paths.add(child)
            if child.is_dir():
                paths.update(path for path in child.rglob("*") if not path.is_symlink())
            continue
        paths.add(child)
        for item in child.iterdir():
            if item.is_symlink():
                continue
            if item.is_file() and (item.name == "catalog.json" or item.name.startswith("catalog.json.")):
                paths.add(item)
            elif item.is_dir() and item.name == "gallery-cache":
                paths.add(item)
                paths.update(path for path in item.rglob("*") if not path.is_symlink())
    return sorted(paths, key=lambda path: (len(path.relative_to(DATA_DIR).parts), str(path)))


def _copy_database(destination):
    source_uri = DATABASE.resolve().as_uri() + "?mode=ro"
    with closing(sqlite3.connect(source_uri, uri=True, timeout=30)) as source:
        with closing(sqlite3.connect(destination, timeout=30)) as target:
            source.backup(target, pages=1000, sleep=0.1)
            target.commit()
    with closing(sqlite3.connect(destination.as_uri() + "?mode=ro", uri=True, timeout=30)) as check:
        result = check.execute("PRAGMA integrity_check").fetchone()
    if not result or result[0] != "ok":
        raise RuntimeError("SQLite integrity check failed")


def _prune_old_archives():
    archives = sorted(BACKUP_DIR.glob("precalc-admin-*.tar.gz"), reverse=True)
    for archive in archives[RETENTION_COUNT:]:
        archive.unlink()
    return min(len(archives), RETENTION_COUNT)


def create_backup():
    if os.geteuid() != 0:
        raise PermissionError("backup must run as root")
    for path in (DATABASE, ENV_FILE):
        if not path.is_file():
            raise FileNotFoundError(path.name)
    if not MEDIA_DIR.is_dir():
        raise FileNotFoundError("media directory")

    BACKUP_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chown(BACKUP_DIR, 0, 0)
    os.chmod(BACKUP_DIR, 0o700)
    source_bytes = DATABASE.stat().st_size + ENV_FILE.stat().st_size + _media_size()
    if shutil.disk_usage(BACKUP_DIR).free < source_bytes + MINIMUM_FREE_BYTES:
        raise OSError("insufficient free space for a safe backup")

    started = utc_now()
    archive_name = f"precalc-admin-{started.strftime('%Y%m%dT%H%M%S%fZ')}.tar.gz"
    final_archive = BACKUP_DIR / archive_name
    with tempfile.TemporaryDirectory(prefix=".precalc-admin-backup-", dir=BACKUP_DIR) as work:
        work_dir = Path(work)
        database_copy = work_dir / "db.sqlite3"
        archive_tmp = work_dir / "snapshot.tar.gz"
        _copy_database(database_copy)
        with tarfile.open(archive_tmp, mode="w:gz", compresslevel=6) as archive:
            archive.add(database_copy, arcname="db.sqlite3", recursive=False)
            for path in _media_backup_paths():
                archive.add(path, arcname=str(path.relative_to(DATA_DIR)), recursive=False)
            archive.add(ENV_FILE, arcname="etc/precalc-admin.env", recursive=False)

        with gzip.open(archive_tmp, "rb") as compressed:
            while compressed.read(1024 * 1024):
                pass
        with tarfile.open(archive_tmp, mode="r:gz") as archive:
            names = {member.name for member in archive.getmembers()}
        if not {"db.sqlite3", "media", "etc/precalc-admin.env"}.issubset(names):
            raise RuntimeError("backup archive is incomplete")
        disallowed_audio_paths = [
            name for name in names
            if name.startswith("media/spcboy/")
            and not name.startswith("media/spcboy/gallery-cache/")
            and not name.startswith("media/spcboy/catalog.json")
            and name != "media/spcboy/gallery-cache"
        ]
        if disallowed_audio_paths:
            raise RuntimeError("backup archive unexpectedly contains SPCBOY audio paths")

        os.chmod(archive_tmp, 0o600)
        os.replace(archive_tmp, final_archive)

    retained = _prune_old_archives()
    _write_status({
        "state": "success",
        "last_success_at": utc_stamp(started),
        "last_success_size_bytes": final_archive.stat().st_size,
        "retained_count": retained,
        "last_failure_at": _read_status().get("last_failure_at", ""),
        "last_failure_code": _read_status().get("last_failure_code", ""),
    })
    print(f"Created {archive_name} ({final_archive.stat().st_size} bytes); {retained} retained.")


def main():
    try:
        create_backup()
    except Exception as error:
        try:
            _write_status({
                "state": "failed",
                "last_failure_at": utc_stamp(utc_now()),
                "last_failure_code": type(error).__name__,
            })
        except Exception:
            pass
        print(f"Private admin backup failed ({type(error).__name__}): {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
