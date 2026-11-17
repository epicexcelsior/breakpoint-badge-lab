"""One-command build, test, package, demo, and physical-badge tooling."""
import argparse
import datetime
import glob
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parent.parent
APPS = ROOT / "apps"
CACHE = ROOT / ".cache"
ARTIFACTS = ROOT / "artifacts"
PERMISSIONS = {"led", "wifi", "mesh", "ble", "lamps", "items", "profile", "quest", "http", "rpc", "mail", "background", "files", "inventory", "gossip"}


def run(args):
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def app_dirs():
    return sorted(p.parent for p in APPS.glob("*/app.json"))


def app_dir(name):
    for p in app_dirs():
        if name in (p.name, json.loads((p / "app.json").read_text())["id"]):
            return p
    raise ValueError(f"Unknown app {name!r}. Choose: {', '.join(p.name for p in app_dirs())}")


def files(app):
    return sorted(p for p in app.rglob("*") if p.is_file() and p.name != "README.md")


def validate(app):
    manifest = json.loads((app / "app.json").read_text())
    if not re.fullmatch(r"[a-z0-9-]{3,24}", manifest.get("id", "")):
        raise ValueError(f"{app.name}: invalid app ID")
    if not isinstance(manifest.get("name"), str) or not 1 <= len(manifest["name"]) <= 20:
        raise ValueError(f"{app.name}: name must contain 1–20 characters")
    if not re.fullmatch(r"\d+\.\d+\.\d+", manifest.get("version", "")):
        raise ValueError(f"{app.name}: version must be major.minor.patch")
    if manifest.get("category") not in {"games", "tools", "social", "quests", "demos"}:
        raise ValueError(f"{app.name}: unsupported category")
    if not re.fullmatch(r"[A-Fa-f0-9]{6}", manifest.get("accent", "")):
        raise ValueError(f"{app.name}: accent must be six hex digits")
    permissions = manifest.get("permissions", [])
    if not isinstance(permissions, list) or any(not isinstance(p, str) or p not in PERMISSIONS for p in permissions):
        raise ValueError(f"{app.name}: invalid permissions")
    if len(set(permissions)) != len(permissions):
        raise ValueError(f"{app.name}: duplicate permission")
    hosts = manifest.get("hosts", [])
    if not isinstance(hosts, list) or any(not isinstance(h, str) or not re.fullmatch(r"[a-z0-9.-]+", h) for h in hosts):
        raise ValueError(f"{app.name}: invalid hosts")
    shipped = files(app)
    main = app / "main.lua"
    if main not in shipped or main.stat().st_size > 65536:
        raise ValueError(f"{app.name}: main.lua is required and must be at most 64 KB")
    extras = []
    for path in shipped:
        rel = path.relative_to(app).as_posix()
        if path.is_symlink() or any(parent.is_symlink() for parent in path.parents if parent != app.parent):
            raise ValueError(f"{app.name}: symlink forbidden: {rel}")
        if len(rel) > 64 or len(path.relative_to(app).parts) > 4 or not re.fullmatch(r"[a-z0-9_./-]+", rel):
            raise ValueError(f"{app.name}: invalid bundled path: {rel}")
        if any(part.startswith(".") or part.endswith(".") for part in path.relative_to(app).parts):
            raise ValueError(f"{app.name}: invalid path component: {rel}")
        if rel in {"app.wasm", "app.aot", "code.bin", "data.json"}:
            raise ValueError(f"{app.name}: reserved runtime path: {rel}")
        if rel not in {"main.lua", "app.json"}:
            extras.append(path)
            if path.stat().st_size > 262144:
                raise ValueError(f"{app.name}: bundled file exceeds 256 KB: {rel}")
        if path.suffix == ".lua":
            text = path.read_text(encoding="utf-8")
            for module in ("led", "wifi", "mesh", "ble", "lamps", "items", "profile", "quest", "http", "rpc"):
                if re.search(r"\b" + module + r"\s*\.\s*[a-z_][a-z0-9_]*\s*\(", text) and module not in permissions:
                    raise ValueError(f"{app.name}: {rel} uses {module} without permission")
    if len(extras) > 64 or sum(p.stat().st_size for p in extras) > 1048576:
        raise ValueError(f"{app.name}: bundled files exceed platform limits")
    return manifest, shipped


def verify():
    manifest = json.loads((ROOT / "docs/sources.json").read_text())
    for item in manifest["files"]:
        path = ROOT / item["path"]
        if not path.is_file() or path.stat().st_size != item["bytes"] or digest(path) != item["sha256"]:
            raise ValueError(f"Archived source changed: {item['path']}")
    lock = json.loads((ROOT / "tools/emulator-lock.json").read_text())
    for name, item in lock["files"].items():
        path = ROOT / "vendor/emulator" / name
        if digest(path) != item["sha256"]:
            raise ValueError(f"Official firmware emulator changed: {name}")
    print(f"Verified {len(manifest['files'])} archived sources and emulator checksums.", flush=True)


def build_runner():
    CACHE.mkdir(exist_ok=True)
    runner = CACHE / "badge-lua"
    inputs = sorted((ROOT / "vendor/lua").glob("*.c")) + [ROOT / "tools/lua_runner.c"]
    key = hashlib.sha256(b"".join(p.read_bytes() for p in inputs) + b"runner-O2-v1").hexdigest()
    stamp = CACHE / "lua-build.sha256"
    if not runner.exists() or not stamp.exists() or stamp.read_text() != key:
        compiler = shutil.which("cc")
        if not compiler:
            raise ValueError("Install a C compiler providing 'cc', then run this command again.")
        run([compiler, "-O2", "-std=c99", "-I", ROOT / "vendor/lua", *inputs, "-lm", "-o", runner])
        stamp.write_text(key)
    return runner


def check():
    runner = build_runner()
    for app in app_dirs():
        manifest, shipped = validate(app)
        run([runner, "--check", *(p for p in shipped if p.suffix == ".lua")])
        print(f"Valid {manifest['id']} {manifest['version']}: {len(shipped)} files", flush=True)


def unit():
    runner = build_runner()
    for path in sorted((ROOT / "tests").glob("test_*.lua")):
        run([runner, path])
    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"])


def emulator():
    verify()
    if not shutil.which("node"):
        raise ValueError("Install Node.js 22 or newer to run the official firmware emulator.")
    run(["node", ROOT / "tools/emulator.mjs", "test"])


def package():
    check()
    out = ARTIFACTS / "release"
    out.mkdir(parents=True, exist_ok=True)
    checksums = []
    for app in app_dirs():
        manifest, shipped = validate(app)
        name = f"{manifest['id']}-{manifest['version']}.zip"
        target = out / name
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path in shipped:
                info = zipfile.ZipInfo(path.relative_to(app).as_posix(), (2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())
        with zipfile.ZipFile(target) as archive:
            if archive.testzip() is not None:
                raise ValueError(f"Invalid ZIP: {target}")
        checksums.append(f"{digest(target)}  {name}")
        print(f"Packaged {target.relative_to(ROOT)} ({target.stat().st_size} bytes)", flush=True)
    (out / "SHA256SUMS").write_text("\n".join(checksums) + "\n")


def test():
    verify()
    check()
    unit()
    emulator()
    package()
    print("All automated checks passed. Physical hardware acceptance remains separate.", flush=True)


def doctor():
    print(f"Python {sys.version.split()[0]}")
    for tool in ("node", "cc", "git", "gh"):
        print(f"{tool}: {'available' if shutil.which(tool) else 'missing'}")
    print("USB serial library:", "available" if importlib.util.find_spec("serial") else "optional, install requirements-usb.txt")
    ports = sorted(glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*") + glob.glob("/dev/cu.usbserial*"))
    print("Serial devices:", ", ".join(ports) if ports else "none detected (emulator still works)")
    verify()


def revision():
    h = hashlib.sha256()
    for app in app_dirs():
        for p in files(app):
            h.update(p.relative_to(ROOT).as_posix().encode()); h.update(p.read_bytes())
    return h.hexdigest()


def demo(port, dev=False):
    check()
    package()
    revision_file = ARTIFACTS / "demo-revision.txt"
    revision_file.write_text(revision())
    server = subprocess.Popen(["node", str(ROOT / "tools/emulator.mjs"), "serve", str(port)], cwd=ROOT)
    try:
        if not dev:
            server.wait()
            return
        last = revision()
        print("Watching app files. A passing check reloads the demo.", flush=True)
        while server.poll() is None:
            time.sleep(1)
            current = revision()
            if current == last:
                continue
            last = current
            try:
                check(); unit(); package()
                revision_file.write_text(current)
                print("Checked and rebuilt. Demo reload enabled.", flush=True)
            except (ValueError, subprocess.CalledProcessError) as error:
                print(f"Change failed checks: {error}. Fix the files and save again.", file=sys.stderr, flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        if server.poll() is None:
            server.terminate()
        server.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)
    for name in ("doctor", "verify", "check", "unit", "emulator", "test", "package"):
        subs.add_parser(name)
    for name in ("demo", "dev"):
        p = subs.add_parser(name); p.add_argument("--port", type=int, default=8765)
    p = subs.add_parser("usb"); p.add_argument("app"); p.add_argument("--port")
    p = subs.add_parser("console"); p.add_argument("--port"); p.add_argument("commands", nargs="+", help='Example: "info" "lua mem" "shot"')
    args = parser.parse_args()
    os.chdir(ROOT)
    try:
        if args.command in {"demo", "dev"}:
            demo(args.port, args.command == "dev")
        elif args.command in {"usb", "console"}:
            from tools.serial_badge import load, console
            if args.command == "usb":
                check(); load(app_dir(args.app), args.port)
            else:
                console(args.port, args.commands)
        else:
            globals()[args.command]()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"badge: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
