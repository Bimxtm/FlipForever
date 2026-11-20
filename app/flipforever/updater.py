"""Self-update from GitHub Releases.

check()  -> asks GitHub for the newest release and compares it with this version
install() -> downloads the release zip, verifies its SHA-256 against SHA256SUMS.txt,
             unpacks it next to the app and swaps the files in after the app closes
             (your data\\ folder is never touched), then restarts the app.

Private repositories need a personal access token (read-only "Contents" permission is
enough); public ones don't.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

from .store import APP_DIR
from .version import CHECKSUM_ASSET, GITHUB_REPO, RELEASE_ASSET_PREFIX, VERSION

API = "https://api.github.com"
UA = "FlipForever-updater"


class UpdateError(Exception):
    pass


@dataclass
class Release:
    version: str
    tag: str
    name: str
    notes: str
    published: str
    url: str
    zip_asset: dict | None
    sums_asset: dict | None


def parse_version(v: str) -> tuple:
    nums = re.findall(r"\d+", v or "")
    return tuple(int(n) for n in nums[:3]) + (0,) * (3 - len(nums[:3]))


def is_newer(remote: str, local: str = VERSION) -> bool:
    return parse_version(remote) > parse_version(local)


def _request(url: str, token: str = "", accept: str = "application/vnd.github+json", timeout: int = 20):
    headers = {"User-Agent": UA, "Accept": accept, "X-GitHub-Api-Version": "2022-11-28"}
    if token:
        headers["Authorization"] = f"Bearer {token.strip()}"
    req = urllib.request.Request(url, headers=headers)
    try:
        return urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            raise UpdateError("No release found. If the repository is private, add a GitHub token "
                              "in About & updates (read-only access is enough).") from e
        if e.code in (401, 403):
            raise UpdateError("GitHub refused the request - check the token, or try again later "
                              f"(GitHub limits checks without a token). [{e.code}]") from e
        raise UpdateError(f"GitHub error {e.code}") from e
    except urllib.error.URLError as e:
        raise UpdateError(f"Can't reach GitHub: {e.reason}") from e


def latest(token: str = "") -> Release:
    with _request(f"{API}/repos/{GITHUB_REPO}/releases/latest", token) as r:
        data = json.load(r)
    tag = data.get("tag_name") or ""
    assets = data.get("assets") or []
    zip_asset = next((a for a in assets if a["name"].startswith(RELEASE_ASSET_PREFIX) and a["name"].endswith(".zip")), None)
    sums_asset = next((a for a in assets if a["name"] == CHECKSUM_ASSET), None)
    return Release(version=tag.lstrip("v"), tag=tag, name=data.get("name") or tag, notes=data.get("body") or "",
                   published=(data.get("published_at") or "")[:10], url=data.get("html_url") or "",
                   zip_asset=zip_asset, sums_asset=sums_asset)


def _download(asset: dict, token: str, dest: Path, progress=None):
    # the API asset URL works for private and public repos alike
    with _request(asset["url"], token, accept="application/octet-stream", timeout=120) as r, open(dest, "wb") as fh:
        total = int(r.headers.get("Content-Length") or asset.get("size") or 0)
        done = 0
        while True:
            chunk = r.read(1 << 16)
            if not chunk:
                break
            fh.write(chunk)
            done += len(chunk)
            if progress and total:
                progress(done / total)


def install(rel: Release, token: str = "", progress=None) -> Path:
    """Download + verify + unpack. Returns the folder with the new files (call apply_and_restart next)."""
    if not rel.zip_asset:
        raise UpdateError("This release has no FlipForever zip attached.")
    if not rel.sums_asset:
        raise UpdateError("This release has no SHA256SUMS.txt - refusing to install an unverified download.")
    work = Path(tempfile.mkdtemp(prefix="flipforever-update-"))
    zpath = work / rel.zip_asset["name"]
    _download(rel.zip_asset, token, zpath, progress)
    sums = work / CHECKSUM_ASSET
    _download(rel.sums_asset, token, sums)
    expected = None
    for line in sums.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[-1].lstrip("*") == rel.zip_asset["name"]:
            expected = parts[0].lower()
    actual = hashlib.sha256(zpath.read_bytes()).hexdigest()
    if not expected or expected != actual:
        raise UpdateError("The download doesn't match its checksum - not installed. Try again.")
    staging = work / "new"
    with zipfile.ZipFile(zpath) as z:
        for member in z.namelist():
            target = (staging / member).resolve()
            if not str(target).startswith(str(staging.resolve())):
                raise UpdateError("Unsafe path in the update zip - not installed.")
        z.extractall(staging)
    # the zip contains one top folder "FlipForever"
    inner = staging / "FlipForever"
    if not (inner / "FlipForever.exe").exists():
        raise UpdateError("The update zip doesn't contain FlipForever.exe.")
    return inner


def apply_and_restart(new_dir: Path):
    """Swap the files in once this process has exited, keep data\\, then start the new version."""
    if not getattr(sys, "frozen", False):
        raise UpdateError("Self-update works in FlipForever.exe. (Running from source: use git pull.)")
    pid = os.getpid()
    bat = new_dir.parent / "apply-update.bat"
    bat.write_text(
        "@echo off\r\n"
        ":wait\r\n"
        f'tasklist /FI "PID eq {pid}" | find "{pid}" >nul && (timeout /t 1 /nobreak >nul & goto wait)\r\n'
        f'robocopy "{new_dir}" "{APP_DIR}" /E /XD data /R:3 /W:1 /NFL /NDL /NJH /NJS /NP >nul\r\n'
        f'start "" "{APP_DIR / "FlipForever.exe"}" --updated\r\n',
        encoding="ascii")
    subprocess.Popen(["cmd", "/c", str(bat)], creationflags=0x08000000)  # CREATE_NO_WINDOW


def bundled_addon_version() -> str | None:
    return _toc_version(APP_DIR / "addon" / "FlipForever" / "FlipForever.toc")


def _toc_version(toc: Path) -> str | None:
    try:
        for line in toc.read_text(encoding="utf-8").splitlines():
            if line.lower().startswith("## version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        return None
    return None


def installed_addon_version(addon_path: Path | None) -> str | None:
    return _toc_version(addon_path / "FlipForever.toc") if addon_path else None
