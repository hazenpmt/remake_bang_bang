#!/usr/bin/env python3
"""Audit or safely import image assets without creating duplicate sources."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, UnidentifiedImageError
except ImportError:  # pragma: no cover - reported clearly at runtime
    Image = None
    UnidentifiedImageError = OSError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSET_ROOT = PROJECT_ROOT / "assets"
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tga", ".svg"}
RASTER_SUFFIXES = IMAGE_SUFFIXES - {".svg"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pixel_hash(path: Path) -> str | None:
    """Return a decoded-pixel hash without resizing/re-encoding the image."""
    if path.suffix.lower() not in RASTER_SUFFIXES:
        return None
    if Image is None:
        raise RuntimeError("Pillow is required for decoded-pixel duplicate checks.")
    with Image.open(path) as image:
        # Animation timing/disposal is meaningful content.  Do not declare two
        # animations equivalent merely because their decoded frames happen to
        # match; byte hashing still catches literal animation copies.
        if int(getattr(image, "n_frames", 1)) != 1:
            return None
        digest = hashlib.sha256()
        rgba = image.convert("RGBA")
        digest.update(rgba.width.to_bytes(4, "little"))
        digest.update(rgba.height.to_bytes(4, "little"))
        digest.update(rgba.tobytes())
        return digest.hexdigest()


def images(root: Path) -> Iterable[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    )


def display_path(path: Path, asset_root: Path) -> str:
    path_resolved = path.resolve()
    try:
        asset_relative = path_resolved.relative_to(asset_root.resolve())
        return "res://assets/" + asset_relative.as_posix()
    except ValueError:
        pass
    try:
        relative = path_resolved.relative_to(PROJECT_ROOT.resolve())
    except ValueError:
        return str(path_resolved)
    return "res://" + relative.as_posix()


def canonical_path(paths: Iterable[Path], asset_root: Path) -> Path:
    """Choose one stable existing path to print as the reusable resource."""

    preferred_roots = (
        "ui/common/",
        "catalog/",
        "animations/shared_shapes/",
        "battle/shared/",
    )

    def score(path: Path) -> tuple[int, int, int, str]:
        relative = path.resolve().relative_to(asset_root.resolve()).as_posix()
        preferred = 0 if relative.startswith(preferred_roots) else 1
        return preferred, len(Path(relative).parts), len(relative), relative.casefold()

    return min(paths, key=score)


def ordered_matches(paths: Iterable[Path], asset_root: Path) -> list[Path]:
    values = list(paths)
    if not values:
        return []
    canonical = canonical_path(values, asset_root)
    return [canonical] + sorted(
        (path for path in values if path != canonical),
        key=lambda path: display_path(path, asset_root).casefold(),
    )


def index_assets(asset_root: Path) -> tuple[dict[str, list[Path]], dict[str, list[Path]]]:
    byte_index: dict[str, list[Path]] = defaultdict(list)
    pixel_index: dict[str, list[Path]] = defaultdict(list)
    for path in images(asset_root):
        byte_index[sha256(path)].append(path)
        decoded = pixel_hash(path)
        if decoded is not None:
            pixel_index[decoded].append(path)
    return byte_index, pixel_index


def report_group(kind: str, paths: list[Path], asset_root: Path) -> None:
    print(f"{kind}: {len(paths)} copies")
    ordered = ordered_matches(paths, asset_root)
    print(f"  CANONICAL {display_path(ordered[0], asset_root)}")
    for path in ordered[1:]:
        print(f"  DUPLICATE {display_path(path, asset_root)}")


def json_group(paths: list[Path], asset_root: Path) -> dict[str, object]:
    ordered = ordered_matches(paths, asset_root)
    return {
        "canonical": display_path(ordered[0], asset_root),
        "duplicates": [
            display_path(path, asset_root) for path in ordered[1:]
        ],
    }


def scan(asset_root: Path, as_json: bool) -> int:
    byte_index, pixel_index = index_assets(asset_root)
    byte_groups = [paths for paths in byte_index.values() if len(paths) > 1]
    byte_duplicate_paths = {path.resolve() for group in byte_groups for path in group}
    pixel_groups = []
    for paths in pixel_index.values():
        if len(paths) < 2:
            continue
        byte_hashes = {sha256(path) for path in paths}
        if len(byte_hashes) > 1:
            pixel_groups.append(paths)

    if as_json:
        print(
            json.dumps(
                {
                    "byte_duplicate_groups": [
                        json_group(group, asset_root) for group in byte_groups
                    ],
                    "pixel_duplicate_groups": [
                        json_group(group, asset_root) for group in pixel_groups
                    ],
                    "byte_duplicate_path_count": len(byte_duplicate_paths),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        for group in byte_groups:
            report_group("BYTE_DUPLICATE", group, asset_root)
        for group in pixel_groups:
            report_group("PIXEL_DUPLICATE", group, asset_root)
        print(
            f"scan: {len(byte_groups)} byte groups, "
            f"{len(pixel_groups)} re-encoded pixel groups"
        )
    return 1 if byte_groups or pixel_groups else 0


def candidate_matches(source: Path, asset_root: Path) -> tuple[str | None, list[Path]]:
    byte_index, pixel_index = index_assets(asset_root)
    exact = byte_index.get(sha256(source), [])
    if exact:
        return "BYTE_DUPLICATE", ordered_matches(exact, asset_root)
    decoded = pixel_hash(source)
    if decoded is not None:
        matches = pixel_index.get(decoded, [])
        if matches:
            return "PIXEL_DUPLICATE", ordered_matches(matches, asset_root)
    return None, []


def candidate(source: Path, asset_root: Path, as_json: bool) -> int:
    kind, matches = candidate_matches(source, asset_root)
    payload = {
        "candidate": str(source.resolve()),
        "status": kind or "UNIQUE",
        "canonical": display_path(matches[0], asset_root) if matches else None,
        "existing": [display_path(path, asset_root) for path in matches],
    }
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    elif kind:
        print(f"{kind}: do not copy {source}")
        print(f"Use existing asset: {payload['existing'][0]}")
    else:
        print(f"UNIQUE: {source}")
    return 1 if kind else 0


def resolve_destination(destination: Path, asset_root: Path) -> Path:
    """Resolve CLI destinations relative to assets, independent of the CWD."""

    if destination.is_absolute():
        return destination.resolve(strict=False)
    parts = destination.parts
    if parts and parts[0].casefold() == "assets":
        return (PROJECT_ROOT / destination).resolve(strict=False)
    return (asset_root / destination).resolve(strict=False)


def import_asset(
    source: Path,
    destination: Path,
    asset_root: Path,
    as_json: bool = False,
) -> int:
    kind, matches = candidate_matches(source, asset_root)
    if kind:
        canonical = display_path(matches[0], asset_root)
        if as_json:
            print(json.dumps({
                "status": kind,
                "imported": None,
                "canonical": canonical,
                "existing": [display_path(path, asset_root) for path in matches],
            }, ensure_ascii=False, indent=2))
        else:
            print(f"{kind}: import refused.")
            print(f"Use existing asset: {canonical}")
        return 1
    asset_root_resolved = asset_root.resolve()
    destination_resolved = resolve_destination(destination, asset_root)
    try:
        destination_resolved.relative_to(asset_root_resolved)
    except ValueError:
        print("ERROR: destination must stay inside the project assets directory.", file=sys.stderr)
        return 2
    source_suffix = source.suffix.casefold()
    destination_suffix = destination_resolved.suffix.casefold()
    same_format = source_suffix == destination_suffix or {
        source_suffix,
        destination_suffix,
    } == {".jpg", ".jpeg"}
    if not same_format:
        print(
            "ERROR: destination must keep the source image extension.",
            file=sys.stderr,
        )
        return 2
    if destination_resolved.exists():
        print(f"ERROR: destination already exists: {destination_resolved}", file=sys.stderr)
        return 2
    destination_resolved.parent.mkdir(parents=True, exist_ok=True)
    source_digest = sha256(source)
    fd, temp_name = tempfile.mkstemp(
        prefix=".asset-import-",
        suffix=".tmp",
        dir=destination_resolved.parent,
    )
    os.close(fd)
    temp_path = Path(temp_name)
    try:
        shutil.copy2(source, temp_path)
        if sha256(temp_path) != source_digest:
            print("ERROR: source changed while it was being copied.", file=sys.stderr)
            return 2
        try:
            # The hard-link commit is atomic and fails if another process
            # created the destination.  Unlike os.replace(), it can never
            # overwrite an existing original asset during a race.
            os.link(temp_path, destination_resolved)
        except FileExistsError:
            print(
                f"ERROR: destination already exists: {destination_resolved}",
                file=sys.stderr,
            )
            return 2
        except OSError as error:
            print(f"ERROR: atomic import failed: {error}", file=sys.stderr)
            return 2
    finally:
        if temp_path.exists():
            temp_path.unlink()
    imported = display_path(destination_resolved, asset_root)
    if as_json:
        print(json.dumps({
            "status": "IMPORTED",
            "imported": imported,
            "canonical": imported,
            "existing": [imported],
        }, ensure_ascii=False, indent=2))
    else:
        print(f"IMPORTED: {imported}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=DEFAULT_ASSET_ROOT,
        help="Assets directory to index (defaults to this project's assets).",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON where supported.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("scan", help="Fail if duplicate images exist under assets.")
    candidate_parser = subparsers.add_parser(
        "candidate", help="Check a warehouse image before copying it."
    )
    candidate_parser.add_argument("source", type=Path)
    import_parser = subparsers.add_parser(
        "import", help="Import only when no existing asset has the same content."
    )
    import_parser.add_argument("source", type=Path)
    import_parser.add_argument("destination", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    asset_root = args.asset_root.resolve()
    try:
        if not asset_root.is_dir():
            print(f"ERROR: assets directory does not exist: {asset_root}", file=sys.stderr)
            return 2
        if args.command == "scan":
            return scan(asset_root, args.json)
        source = args.source.resolve()
        if not source.is_file() or source.suffix.lower() not in IMAGE_SUFFIXES:
            print(f"ERROR: not a supported image: {source}", file=sys.stderr)
            return 2
        if args.command == "candidate":
            return candidate(source, asset_root, args.json)
        return import_asset(source, args.destination, asset_root, args.json)
    except (OSError, RuntimeError, UnidentifiedImageError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
