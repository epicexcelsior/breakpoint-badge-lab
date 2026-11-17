import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.badge import ROOT, validate


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.app = Path(self.tmp.name) / "shipmates"
        shutil.copytree(ROOT / "apps/shipmates", self.app)

    def test_own_app_contents_and_permission_contract(self):
        manifest, paths = validate(self.app)
        self.assertEqual(manifest["permissions"], ["mesh", "led"])
        self.assertEqual({p.relative_to(self.app).as_posix() for p in paths},
                         {"main.lua", "app.json", "lib/radar.lua", "lib/connections.lua"})

    def test_missing_permission_is_rejected(self):
        path = self.app / "app.json"
        manifest = json.loads(path.read_text())
        manifest["permissions"] = []
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "without permission"):
            validate(self.app)

    def test_secret_or_hidden_file_is_rejected(self):
        (self.app / ".env").write_text("placeholder")
        with self.assertRaisesRegex(ValueError, "invalid path"):
            validate(self.app)

    def test_reserved_runtime_file_is_rejected(self):
        (self.app / "data.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "reserved"):
            validate(self.app)

    def test_oversize_entrypoint_is_rejected(self):
        (self.app / "main.lua").write_bytes(b"-" * 65537)
        with self.assertRaisesRegex(ValueError, "64 KB"):
            validate(self.app)


if __name__ == "__main__":
    unittest.main()
