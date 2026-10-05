from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

from PIL import Image


SCRIPT = Path(__file__).resolve().parents[1] / "asset_duplicate_guard.py"
SPEC = importlib.util.spec_from_file_location("asset_duplicate_guard", SCRIPT)
guard = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(guard)


class AssetDuplicateGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name) / "assets"
        self.root.mkdir()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    @staticmethod
    def write_png(path: Path, color: tuple[int, int, int, int], compress: int = 6) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (4, 3), color).save(path, compress_level=compress)

    def test_scan_rejects_byte_duplicate(self) -> None:
        first = self.root / "one.png"
        second = self.root / "nested/two.png"
        self.write_png(first, (255, 0, 0, 255))
        second.parent.mkdir()
        second.write_bytes(first.read_bytes())
        self.assertEqual(guard.scan(self.root, False), 1)

    def test_scan_rejects_same_pixels_with_different_compression(self) -> None:
        self.write_png(self.root / "one.png", (0, 255, 0, 255), 0)
        self.write_png(self.root / "two.png", (0, 255, 0, 255), 9)
        self.assertEqual(guard.scan(self.root, False), 1)

    def test_unique_scan_and_candidate_pass(self) -> None:
        self.write_png(self.root / "one.png", (0, 0, 255, 255))
        candidate = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(candidate, (255, 255, 0, 255))
        self.assertEqual(guard.scan(self.root, False), 0)
        self.assertEqual(guard.candidate(candidate, self.root, False), 0)

    def test_candidate_rejects_existing_pixels(self) -> None:
        self.write_png(self.root / "one.png", (15, 30, 45, 255), 0)
        candidate = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(candidate, (15, 30, 45, 255), 9)
        self.assertEqual(guard.candidate(candidate, self.root, False), 1)

    def test_candidate_reports_preferred_canonical_res_path(self) -> None:
        common = self.root / "ui/common/buttons/close.png"
        feature = self.root / "ui/shop/close.png"
        self.write_png(common, (15, 30, 45, 255))
        feature.parent.mkdir(parents=True)
        feature.write_bytes(common.read_bytes())
        candidate = Path(self.temp_dir.name) / "candidate.png"
        candidate.write_bytes(common.read_bytes())
        output = StringIO()
        with redirect_stdout(output):
            self.assertEqual(guard.candidate(candidate, self.root, True), 1)
        payload = json.loads(output.getvalue())
        self.assertEqual(
            payload["canonical"],
            "res://assets/ui/common/buttons/close.png",
        )

    def test_import_uses_assets_relative_destination_and_preserves_bytes(self) -> None:
        source = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(source, (100, 120, 140, 255))
        self.assertEqual(
            guard.import_asset(source, Path("ui/new/candidate.png"), self.root),
            0,
        )
        destination = self.root / "ui/new/candidate.png"
        self.assertTrue(destination.is_file())
        self.assertEqual(source.read_bytes(), destination.read_bytes())

    def test_import_refuses_duplicate_and_does_not_create_destination(self) -> None:
        existing = self.root / "ui/common/existing.png"
        self.write_png(existing, (100, 120, 140, 255))
        source = Path(self.temp_dir.name) / "candidate.png"
        source.write_bytes(existing.read_bytes())
        destination = self.root / "ui/feature/copied.png"
        self.assertEqual(guard.import_asset(source, destination, self.root), 1)
        self.assertFalse(destination.exists())

    def test_import_refuses_destination_outside_assets(self) -> None:
        source = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(source, (100, 120, 140, 255))
        outside = Path(self.temp_dir.name) / "outside.png"
        self.assertEqual(guard.import_asset(source, outside, self.root), 2)
        self.assertFalse(outside.exists())

    def test_import_refuses_extension_change(self) -> None:
        source = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(source, (100, 120, 140, 255))
        destination = self.root / "candidate.jpg"
        self.assertEqual(guard.import_asset(source, destination, self.root), 2)
        self.assertFalse(destination.exists())

    def test_cli_import_is_independent_of_working_directory(self) -> None:
        source = Path(self.temp_dir.name) / "candidate.png"
        self.write_png(source, (100, 120, 140, 255))
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--asset-root",
                str(self.root),
                "import",
                str(source),
                "ui/new/candidate.png",
            ],
            cwd=Path(self.temp_dir.name),
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertTrue((self.root / "ui/new/candidate.png").is_file())

    def test_cli_import_refuses_existing_asset_and_prints_canonical(self) -> None:
        existing = self.root / "ui/common/existing.png"
        self.write_png(existing, (100, 120, 140, 255))
        source = Path(self.temp_dir.name) / "candidate.png"
        source.write_bytes(existing.read_bytes())
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--asset-root",
                str(self.root),
                "import",
                str(source),
                "ui/feature/copied.png",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 1, completed.stderr)
        self.assertIn(
            "Use existing asset: res://assets/ui/common/existing.png",
            completed.stdout,
        )
        self.assertFalse((self.root / "ui/feature/copied.png").exists())

    def test_import_sidecar_is_ignored(self) -> None:
        self.write_png(self.root / "one.png", (1, 2, 3, 255))
        (self.root / "one.png.import").write_text("not an image")
        self.assertEqual(guard.scan(self.root, False), 0)

    def test_animated_gif_is_only_compared_by_bytes(self) -> None:
        first = self.root / "one.gif"
        second = self.root / "two.gif"
        frames = [
            Image.new("RGBA", (3, 2), (255, 0, 0, 255)),
            Image.new("RGBA", (3, 2), (0, 255, 0, 255)),
        ]
        frames[0].save(
            first,
            save_all=True,
            append_images=frames[1:],
            duration=[50, 50],
            loop=0,
        )
        frames[0].save(
            second,
            save_all=True,
            append_images=frames[1:],
            duration=[100, 100],
            loop=0,
        )
        self.assertIsNone(guard.pixel_hash(first))
        self.assertIsNone(guard.pixel_hash(second))
        self.assertEqual(guard.scan(self.root, False), 0)


if __name__ == "__main__":
    unittest.main()
