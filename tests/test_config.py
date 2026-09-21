"""Offline regression tests; no account, GPU, Docker daemon or host access."""
import grp
import os
from pathlib import Path
import pwd
import subprocess
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / "root/custom-cont-init.d/10-chatgpt-unraid.sh"


class ConfigurationTests(unittest.TestCase):
    def test_shell_syntax(self):
        for directory in (ROOT / "root", ROOT / "tests"):
            for path in directory.rglob("*"):
                if path.is_file() and path.read_bytes().startswith(b"#!/"):
                    with self.subTest(path=path):
                        subprocess.run(["bash", "-n", str(path)], check=True)

    def test_template(self):
        config = ET.parse(ROOT / "unraid/chatgpt-community.xml").getroot()
        self.assertEqual(config.findtext("Name"), "ChatGPT-Community")
        self.assertEqual(config.findtext("Privileged"), "false")
        settings = {node.attrib["Target"]: node for node in config.findall("Config")}
        self.assertEqual(settings["/config"].text, "/mnt/user/appdata/chatgpt-community")
        self.assertEqual(settings["/dev/dri"].attrib["Type"], "Device")
        self.assertEqual(settings["PASSWORD"].attrib["Mask"], "true")
        self.assertNotIn("/var/run/docker.sock", settings)

    def run_init(self, directory):
        env = os.environ | {
            "CHATGPT_CONFIG_DIR": str(directory),
            "CHATGPT_DEFAULTS_DIR": str(ROOT / "root/defaults"),
            "CHATGPT_APP_USER": pwd.getpwuid(os.getuid()).pw_name,
            "CHATGPT_APP_GROUP": grp.getgrgid(os.getgid()).gr_name,
            "UNRAID_HOST": "192.0.2.1",
            "PASSWORD": "test-only",
        }
        result = subprocess.run(["bash", str(INIT)], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("ssh-keygen"), "OpenSSH client is required")
    def test_migration_preserves_credentials_and_user_edits(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            preserved = {
                ".codex/auth.json": '{"test":"existing-account"}\n',
                ".config/Codex/Local State": '{"test":"existing-profile"}\n',
                ".config/codex-desktop/remote-control-device-keys/keys.json": "paired-device\n",
                ".config/codex-desktop/electron-flags.conf": "--no-sandbox\n",
                ".ssh/config": "Host unraid\n    HostName 192.0.2.123\n",
                ".ssh/known_hosts": "existing-known-host\n",
                "workspace/unraid/AGENTS.md": "User-customized instructions\n",
            }
            for name, value in preserved.items():
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            legacy = directory / ".config/autostart/chatgpt-community.desktop"
            legacy.parent.mkdir(parents=True)
            legacy.write_text("[Desktop Entry]\nExec=old-launcher\n")
            for wm in ("labwc", "openbox"):
                path = directory / f".config/{wm}/autostart"
                path.parent.mkdir(parents=True)
                path.write_text("exit 0\n")
            self.run_init(directory)
            key = (directory / ".ssh/id_ed25519").read_bytes()
            self.run_init(directory)
            self.assertEqual(key, (directory / ".ssh/id_ed25519").read_bytes())
            for name, value in preserved.items():
                with self.subTest(path=name):
                    self.assertEqual((directory / name).read_text(), value)
            backup = directory / ".local/state/chatgpt-community/migration-single-app-v1"
            self.assertFalse(legacy.exists())
            self.assertTrue((backup / "chatgpt-community.desktop").exists())
            for wm in ("labwc", "openbox"):
                self.assertEqual((backup / f"{wm}-autostart").read_text(), "exit 0\n")
                self.assertIn("start-chatgpt-community", (directory / f".config/{wm}/autostart").read_text())

    @unittest.skipUnless(shutil.which("ssh-keygen"), "OpenSSH client is required")
    def test_fresh_config_and_missing_public_key(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.run_init(directory)
            self.assertIn("ssh unraid", (directory / "workspace/unraid/AGENTS.md").read_text())
            original = (directory / ".ssh/id_ed25519").read_bytes()
            (directory / ".ssh/id_ed25519.pub").unlink()
            self.run_init(directory)
            self.assertEqual(original, (directory / ".ssh/id_ed25519").read_bytes())
            self.assertTrue((directory / ".ssh/id_ed25519.pub").read_text().startswith("ssh-ed25519 "))


if __name__ == "__main__":
    unittest.main()
