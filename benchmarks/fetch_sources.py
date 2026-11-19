"""Fetch the pinned public model files and verify local project dependencies."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tarfile
import tempfile
from urllib.request import urlopen

TOOL = Path(__file__).resolve().parents[1]
LOCK = json.loads((TOOL / "benchmarks" / "source-lock.json").read_text())
TARGET = TOOL / "verification" / "sources"
LEGACY_TEXT = {entry["path"]: entry["encoding"] for entry in LOCK["legacy_text"]}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def matches(path, expected):
    if not path.is_file():
        return False
    data = path.read_bytes()
    if digest(data) == expected:
        return True
    encoding = LEGACY_TEXT.get(path.relative_to(TARGET).as_posix())
    if encoding:
        # The toolbox carries UTF-8 text. Check the exact pinned upstream bytes.
        try:
            if digest(data.decode("utf-8").encode(encoding)) == expected:
                return True
        except UnicodeError:
            pass
    raise ValueError(f"Existing file has a different SHA-256: {path}")


def install(key, data, expected):
    path = TARGET / key
    if digest(data) != expected:
        raise ValueError(f"Downloaded SHA-256 mismatch: {key}")
    path.parent.mkdir(parents=True, exist_ok=True)
    if matches(path, expected):
        return
    with tempfile.NamedTemporaryFile(dir=path.parent) as temp:
        temp.write(data)
        temp.flush()
        try:
            os.link(temp.name, path)
        except FileExistsError:
            matches(path, expected)


def fetch_arch(keys):
    ref = LOCK["ARCH"]
    url = f"https://gitlab.com/api/v4/projects/goranf%2FARCH-COMP/repository/archive.tar.gz?sha={ref}&path=models%2FFALS"
    with urlopen(url, timeout=120) as stream, tarfile.open(fileobj=stream, mode="r|gz") as archive:
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if not member.isfile() or "FALS" not in parts:
                continue
            key = "/".join(("ARCH", *parts[parts.index("FALS") + 1:]))
            if key in keys:
                install(key, archive.extractfile(member).read(), LOCK["sha256"][key])
                keys.remove(key)
    if keys:
        raise FileNotFoundError(f"Missing in ARCH archive: {sorted(keys)}")


def fetch_github(key):
    family, name = key.split("/", 1)
    if family == "SB":
        repo = "lyudeyun/FalBenchGen_ARCHCOMP25"
        directory = {".slx": "benchmark/simulink/", ".mat": "benchmark/lstm/",
                     ".m": "scripts/staliro_simulink/"}.get(Path(name).suffix, "")
    else:
        repo = "3MD3/3MD3"
        directory = "" if name == "README.md" else "Model1/"
    url = f"https://raw.githubusercontent.com/{repo}/{LOCK[family]}/{directory}{name}"
    with urlopen(url, timeout=60) as response:
        install(key, response.read(), LOCK["sha256"][key])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=TOOL.parent,
                        help="Project directory containing Falsify and the previous AT experiment")
    args = parser.parse_args()
    missing = {key for key, sha in LOCK["sha256"].items() if not matches(TARGET / key, sha)}
    arch = {key for key in missing if key.startswith("ARCH/")}
    if arch:
        fetch_arch(arch)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(fetch_github, sorted(k for k in missing if not k.startswith("ARCH/"))))
    for key, spec in LOCK["project_support"].items():
        if not matches(TARGET / key, spec["sha256"]):
            source = args.project / spec["path"]
            if not source.is_file():
                raise FileNotFoundError(f"Required project asset: {source}. Use --project to select the project directory.")
            install(key, source.read_bytes(), spec["sha256"])
    print(f"Verified {len(LOCK['sha256'])} upstream files and {len(LOCK['project_support'])} project files.")


if __name__ == "__main__":
    main()
