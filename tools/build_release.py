"""Build a FlipForever release into dist/:

  dist/FlipForever-v<version>.zip   the app folder (exe + addon + tools + docs), no user data
  dist/SHA256SUMS.txt               checksum the in-app updater verifies
  dist/release-notes.md             NEWS.md + this version's CHANGELOG section (paste as release text)

Steps for a new version:
  1. bump VERSION in app/flipforever/version.py and ## Version in addon/FlipForever/FlipForever.toc
  2. add a section to CHANGELOG.md, rewrite NEWS.md
  3. python tools/build_release.py   (needs: pip install pyinstaller)
  4. commit + push, create a GitHub release with tag v<version>, upload the zip and SHA256SUMS.txt
"""
import hashlib
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "app"))
from flipforever.version import VERSION  # noqa: E402

DIST = ROOT / "dist"
INCLUDE = ["FlipForever.exe", "addon", "tools", "README.md", "CHANGELOG.md", "NEWS.md", "flipforever.ico"]


def check_versions():
    toc = (ROOT / "addon" / "FlipForever" / "FlipForever.toc").read_text(encoding="utf-8")
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not m or m.group(1) != VERSION:
        sys.exit(f"Addon TOC version ({m and m.group(1)}) != app version ({VERSION}) - bump both.")
    if f"## [{VERSION}]" not in (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"):
        sys.exit(f"CHANGELOG.md has no section for {VERSION}.")


EXE_OUT = DIST / "exe"


def build_exe(skip: bool):
    """Builds into dist/exe/ so a running FlipForever.exe in the project folder is never touched."""
    if skip and (EXE_OUT / "FlipForever.exe").exists():
        return
    work = DIST / "build"
    subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--windowed", "--name", "FlipForever",
                    "--icon", str(ROOT / "flipforever.ico"), "--paths", str(ROOT / "app"), "--distpath", str(EXE_OUT),
                    "--workpath", str(work), "--specpath", str(work), "--log-level", "WARN",
                    str(ROOT / "FlipForever.pyw")], check=True)


def refresh_local_exe():
    """Put the new exe in the project folder too - only if the app isn't running (file would be locked)."""
    try:
        shutil.copy2(EXE_OUT / "FlipForever.exe", ROOT / "FlipForever.exe")
        print("local FlipForever.exe updated")
    except PermissionError:
        print("FlipForever.exe is open - your copy updates through About & updates (or rerun later)")


def make_zip() -> Path:
    zpath = DIST / f"FlipForever-v{VERSION}.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(EXE_OUT / "FlipForever.exe", "FlipForever/FlipForever.exe")
        for name in INCLUDE:
            if name == "FlipForever.exe":
                continue
            p = ROOT / name
            files = [p] if p.is_file() else [f for f in p.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
            for f in files:
                z.write(f, "FlipForever/" + f.relative_to(ROOT).as_posix())
    return zpath


def release_notes() -> str:
    news = (ROOT / "NEWS.md").read_text(encoding="utf-8").strip()
    log = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(rf"^## \[{re.escape(VERSION)}\].*?(?=^## \[|\Z)", log, re.S | re.M)
    section = m.group(0).strip() if m else ""
    return (f"{news}\n\n---\n\n{section}\n\n---\n**Install:** download `FlipForever-v{VERSION}.zip`, unzip, run "
            f"`FlipForever.exe`, then Settings > Install / update the addon. **Update:** in the app, "
            f"About & updates > Check for updates.\n")


def main():
    check_versions()
    DIST.mkdir(exist_ok=True)
    build_exe(skip="--skip-exe" in sys.argv)
    refresh_local_exe()
    z = make_zip()
    digest = hashlib.sha256(z.read_bytes()).hexdigest()
    (DIST / "SHA256SUMS.txt").write_text(f"{digest}  {z.name}\n", encoding="utf-8")
    (DIST / "release-notes.md").write_text(release_notes(), encoding="utf-8")
    shutil.rmtree(DIST / "build", ignore_errors=True)
    print(f"built {z.name} ({z.stat().st_size / 1e6:.1f} MB), sha256 {digest[:16]}...")
    print(f"tag: v{VERSION}   upload: {z.name}, SHA256SUMS.txt   text: dist/release-notes.md")


if __name__ == "__main__":
    main()
