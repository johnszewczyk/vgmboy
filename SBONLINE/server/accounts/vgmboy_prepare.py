"""Bounded process adapter for the online player's archive/member preparation."""

import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time

from django.conf import settings

MAX_PREPARED_MEMBER_BYTES = 128 * 1024 * 1024
PREPARATION_TIMEOUT_SECONDS = 60


def _prepare_zstd_tar_member(archive_path, member_name, output_path, environment, deadline):
    """Read one member from legacy Master UACs that contain a plain zstd tar."""
    decompressor = None
    extractor = None
    written = 0
    try:
        decompressor = subprocess.Popen(
            [environment["VGMBOY_ZSTD_BINARY"], "-d", "-q", "-c", "--", str(archive_path)],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            start_new_session=True, bufsize=0,
        )
        extractor = subprocess.Popen(
            [environment["VGMBOY_TAR_BINARY"], "-x", "-O", "-f", "-", "--", member_name],
            stdin=decompressor.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            start_new_session=True, bufsize=0,
        )
        decompressor.stdout.close()
        with output_path.open("wb") as output, selectors.DefaultSelector() as ready:
            ready.register(extractor.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not ready.select(remaining):
                    raise RuntimeError("Zstandard TAR member preparation timed out.")
                chunk = os.read(extractor.stdout.fileno(), 65536)
                if not chunk:
                    break
                written += len(chunk)
                if written > MAX_PREPARED_MEMBER_BYTES:
                    raise RuntimeError("Zstandard TAR member exceeds the output limit.")
                output.write(chunk)

        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("Zstandard TAR member preparation timed out.")
        tar_status = extractor.wait(timeout=remaining)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("Zstandard TAR member preparation timed out.")
        zstd_status = decompressor.wait(timeout=remaining)
        if tar_status != 0 or zstd_status != 0 or written == 0:
            raise RuntimeError("The selected member was not found in the Zstandard TAR archive.")
        return True
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("Zstandard TAR member preparation timed out.") from error
    finally:
        for process in (extractor, decompressor):
            if process is None:
                continue
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            if process.stdout is not None:
                process.stdout.close()


def prepare_selected_member(archive_path, member_name, output_path):
    """Prepare one source, with request-owned scratch and bounded output/lifetime."""
    output_path = Path(output_path)
    output_path.unlink(missing_ok=True)
    executable = Path(settings.SPCBOY_PREPARE_EXECUTABLE)
    if not executable.exists():
        raise RuntimeError("The VGMBoy preparation runtime is not installed.")
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise RuntimeError("The installed VGMBoy preparation executable is not runnable.")

    environment = os.environ.copy()
    environment["VGMBOY_TAR_BINARY"] = str(settings.SPCBOY_TAR)
    environment["VGMBOY_ZSTD_BINARY"] = str(settings.SPCBOY_ZSTD)
    environment["VGMBOY_7Z_BINARY"] = str(settings.SPCBOY_7Z)
    process = None
    try:
        # A killed helper cannot run Swift defers. Keep all its temporary sources
        # under the request so timeout, disconnect and failure still reclaim them.
        with tempfile.TemporaryDirectory(prefix="vgmboy-source-", dir=output_path.parent) as scratch:
            environment["TMPDIR"] = scratch
            deadline = time.monotonic() + PREPARATION_TIMEOUT_SECONDS
            process = subprocess.Popen(
                [str(executable), str(archive_path), member_name], env=environment,
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                start_new_session=True, bufsize=0,
            )
            try:
                written = 0
                with output_path.open("wb") as output, selectors.DefaultSelector() as ready:
                    ready.register(process.stdout, selectors.EVENT_READ)
                    while True:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0 or not ready.select(remaining):
                            raise RuntimeError("VGMBoy source preparation timed out.")
                        chunk = os.read(process.stdout.fileno(), 65536)
                        if not chunk:
                            break
                        written += len(chunk)
                        if written > MAX_PREPARED_MEMBER_BYTES:
                            raise RuntimeError("VGMBoy returned an oversized archive member.")
                        output.write(chunk)
                result = process.wait(timeout=max(.01, deadline - time.monotonic()))
                if result != 0 or written == 0:
                    output_path.unlink(missing_ok=True)
                    if Path(archive_path).suffix.casefold() == ".uac":
                        return _prepare_zstd_tar_member(
                            archive_path, member_name, output_path, environment, deadline,
                        )
                    raise RuntimeError("VGMBoy could not prepare the selected archive member.")
            finally:
                # Reap archive-tool descendants as well as the Swift helper.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                process.stdout.close()
    except BaseException as error:
        output_path.unlink(missing_ok=True)
        if isinstance(error, (OSError, subprocess.TimeoutExpired)):
            raise RuntimeError("VGMBoy could not prepare the selected archive member.") from error
        raise
    return True
