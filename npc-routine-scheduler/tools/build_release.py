"""Build the source ZIP from an explicit allowlist; no Godot export is performed.
Run with Python 3: python tools/build_release.py
"""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / "release"
RELEASE.mkdir(exist_ok=True)
archive = RELEASE / "npc-routine-scheduler-v1.0.1.zip"
files = [ROOT / name for name in ("project.godot", "icon.svg", "README.md", "LICENSE.txt", "CHANGELOG.md")]
for folder, extensions in (
    ("addons/npc_routine_scheduler", {".gd", ".uid", ".cfg"}),
    ("demo", {".gd", ".uid", ".tscn", ".tres"}),
):
    # Only direct files: do not traverse generated, cache, or unrelated trees.
    files.extend(p for p in (ROOT / folder).iterdir() if p.is_file() and p.suffix in extensions)
files.sort()
assert len(files) >= 17, "Expected addon, demo, documentation and project files"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
    for path in files:
        output.write(path, path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as check:
    assert check.testzip() is None
    assert set(check.namelist()) == {p.relative_to(ROOT).as_posix() for p in files}
    for path in files:
        name = path.relative_to(ROOT).as_posix()
        assert check.read(name) == path.read_bytes(), name
        assert not name.startswith("/") and ".." not in Path(name).parts
        assert not any(part.startswith(".") for part in Path(name).parts)
        if path.suffix in {".gd", ".cfg", ".tres", ".tscn", ".godot", ".md", ".txt"}:
            text = path.read_text(encoding="utf-8")
            assert "C:\\Users\\" not in text and "C:/Users/" not in text, name
print(f"Verified {len(files)} source files; {archive.stat().st_size:,} bytes")
print(f"SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}")
print(archive)
