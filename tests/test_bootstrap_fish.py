"""Check shell setup using temporary homes and mocked account changes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "bootstrap-opensuse-tumbleweed.sh"
SNIPPET = ROOT / "portable/fish/conf.d/hypr-bootstrap.fish"
FISH = shutil.which("fish")


class BootstrapFishTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home_dir = self.root / "home"
        self.home_dir.mkdir()
        self.shell_file = self.root / "account-shell"
        self.shell_file.write_text("/bin/bash\n")
        self.calls = self.root / "sudo-calls"
        self.backup = self.root / "backup"
        self.env = dict(os.environ, HOME=str(self.home_dir),
                        XDG_CONFIG_HOME="", XDG_STATE_HOME=str(self.root / "state"),
                        XDG_DATA_HOME=str(self.root / "data"),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        FISH_TEST_DIR=str(self.root), FISH_TEST_BOOTSTRAP=str(BOOTSTRAP),
                        FISH_TEST_SNIPPET=str(SNIPPET), TERM="xterm-256color",
                        # Stale/inherited values must not select the account or shell.
                        USER="root", SHELL="/usr/bin/fish")

    def run_bootstrap(self, script):
        return subprocess.run(["bash", "-c", '''
source "$FISH_TEST_BOOTSTRAP"
BACKUP_DIR="$FISH_TEST_DIR/backup"
id() { printf 'fixture\n'; }
getent() {
    [[ "$1" == passwd && "$2" == fixture ]] || return 1
    [[ -f "$FISH_TEST_DIR/account-shell" ]] || return 2
    printf 'fixture:x:1000:1000::%s:%s\n' "$HOME" "$(cat "$FISH_TEST_DIR/account-shell")"
}
grep() {
    [[ "$1" == -Fxq && "$2" == /usr/bin/fish && "$3" == /etc/shells ]] || return 1
    return "${FISH_TEST_SHELLS_STATUS:-0}"
}
sudo() {
    printf '%s\n' "$@" >> "$FISH_TEST_DIR/sudo-calls"
    case "$1" in
        chsh)
            [[ "$2" == -s && "$3" == /usr/bin/fish && "$4" == fixture ]] || return 1
            [[ "${FISH_TEST_CHSH_FAIL:-0}" == 0 ]] || return 1
            printf '%s\n' "$3" > "$FISH_TEST_DIR/account-shell"
            ;;
        install) return 0 ;; # Never deploy a system session from a test.
        *) return 1 ;;
    esac
}
''' + script], env=self.env, capture_output=True, text=True, timeout=30)

    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "requires the distro Fish binary")
    def test_changes_installing_account_once_and_saves_previous_shell(self):
        result = self.run_bootstrap("SKIP_PACKAGES=1; configure_fish_shell; configure_fish_shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.shell_file.read_text(), "/usr/bin/fish\n")
        self.assertEqual((self.backup / "login-shell").read_text(), "/bin/bash\n")
        self.assertEqual(self.calls.read_text().splitlines(),
                         ["chsh", "-s", "/usr/bin/fish", "fixture"])

    def test_already_selected_fish_does_not_change_account(self):
        self.shell_file.write_text("/usr/bin/fish\n")
        result = self.run_bootstrap("configure_fish_shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls.exists())
        self.assertFalse(self.backup.exists())

    def test_dry_run_only_reports_shell_change(self):
        result = self.run_bootstrap("DRY_RUN=1; configure_fish_shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sudo chsh -s /usr/bin/fish fixture", result.stdout)
        self.assertEqual(self.shell_file.read_text(), "/bin/bash\n")
        self.assertFalse(self.calls.exists())
        self.assertFalse(self.backup.exists())

    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "requires the distro Fish binary")
    def test_unregistered_shell_is_rejected_before_chsh(self):
        self.env["FISH_TEST_SHELLS_STATUS"] = "1"
        result = self.run_bootstrap("configure_fish_shell")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not registered in /etc/shells", result.stderr)
        self.assertFalse(self.calls.exists())
        self.assertFalse(self.backup.exists())

    def test_failed_account_lookup_does_not_change_shell(self):
        self.shell_file.unlink()
        result = self.run_bootstrap("configure_fish_shell")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot read the login shell", result.stderr)
        self.assertFalse(self.calls.exists())

    @unittest.skipUnless(Path("/usr/bin/fish").is_file(), "requires the distro Fish binary")
    def test_failed_chsh_is_reported_and_backup_is_retained(self):
        self.env["FISH_TEST_CHSH_FAIL"] = "1"
        result = self.run_bootstrap("configure_fish_shell")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.shell_file.read_text(), "/bin/bash\n")
        self.assertEqual((self.backup / "login-shell").read_text(), "/bin/bash\n")

    @unittest.skipUnless(shutil.which("rsync"), "requires rsync")
    def test_deployment_preserves_personal_settings_and_backs_up_managed_files(self):
        for custom_config in (False, True):
            with self.subTest(custom_config=custom_config):
                config_dir = self.home_dir / ("custom-config" if custom_config else ".config")
                self.env["XDG_CONFIG_HOME"] = str(config_dir) if custom_config else ""
                fish_dir = config_dir / "fish"
                (fish_dir / "conf.d").mkdir(parents=True)
                originals = {
                    "config.fish": "set -gx PERSONAL_SETTING preserved\n",
                    "fish_variables": "# Personal universal variables\n",
                    "conf.d/personal.fish": "# Personal shell setup\n",
                    "conf.d/hypr-bootstrap.fish": "# Previous managed snippet\n",
                }
                for name, contents in originals.items():
                    (fish_dir / name).write_text(contents)
                (config_dir / "starship.toml").write_text("# Previous prompt\n")
                result = self.run_bootstrap('''
backup_existing_configuration
printf '%s' "$BACKUP_DIR" > "$FISH_TEST_DIR/backup-path"
deploy_configuration
deploy_configuration
''')
                self.assertEqual(result.returncode, 0, result.stderr)
                backup_dir = Path((self.root / "backup-path").read_text())
                saved_config = backup_dir / config_dir.relative_to(self.home_dir)
                for name, contents in originals.items():
                    self.assertEqual((saved_config / "fish" / name).read_text(), contents)
                    if name != "conf.d/hypr-bootstrap.fish":
                        self.assertEqual((fish_dir / name).read_text(), contents)
                self.assertEqual((saved_config / "starship.toml").read_text(), "# Previous prompt\n")
                self.assertEqual((fish_dir / "conf.d/hypr-bootstrap.fish").read_text(),
                                 SNIPPET.read_text())
                self.assertEqual((config_dir / "starship.toml").read_text(),
                                 (ROOT / "portable/starship/starship.toml").read_text())

    @unittest.skipUnless(FISH, "requires Fish")
    def test_tools_initialize_only_in_interactive_shells(self):
        bin_dir = self.home_dir / ".local/bin"
        bin_dir.mkdir(parents=True)
        for tool in ("zoxide", "starship"):
            executable = bin_dir / tool
            executable.write_text(f'''#!/bin/sh
printf '{tool} %s %s\\n' "$1" "$2" >> "$FISH_TEST_DIR/init-calls"
printf 'set -g {tool}_initialized yes\\n'
''')
            executable.chmod(0o755)
        for interactive in (False, True):
            with self.subTest(interactive=interactive):
                script = 'source "$FISH_TEST_SNIPPET"; contains -- "$HOME/.local/bin" $PATH; or exit 1'
                if interactive:
                    script += '; set -q zoxide_initialized starship_initialized; or exit 1'
                result = subprocess.run([FISH, "--no-config", *(["-i"] if interactive else []),
                                         "-c", script], env=self.env, capture_output=True,
                                        text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                calls = self.root / "init-calls"
                if interactive:
                    self.assertEqual(calls.read_text().splitlines(),
                                     ["zoxide init fish", "starship init fish"])
                else:
                    self.assertFalse(calls.exists())

    @unittest.skipUnless(FISH and shutil.which("zoxide") and shutil.which("starship"),
                         "requires Fish, zoxide and Starship")
    def test_real_shell_loads_snippet_and_uses_xdg_prompt(self):
        config_dir = self.root / "xdg-config"
        snippet_dir = config_dir / "fish/conf.d"
        snippet_dir.mkdir(parents=True)
        shutil.copy2(SNIPPET, snippet_dir)
        (config_dir / "starship.toml").write_text("add_newline = false\nformat = 'fish-smoke > '\n")
        destination = self.root / "destination"
        destination.mkdir()
        self.env.update(XDG_CONFIG_HOME=str(config_dir), FISH_TEST_DEST=str(destination))
        self.env.pop("STARSHIP_CONFIG", None)
        for override in (False, True):
            with self.subTest(explicit_starship_config=override):
                expected_prompt = "fish-smoke > "
                if override:
                    explicit_config = self.root / "custom-prompt.toml"
                    expected_prompt = "personal-prompt > "
                    explicit_config.write_text(f"add_newline = false\nformat = '{expected_prompt}'\n")
                    self.env["STARSHIP_CONFIG"] = str(explicit_config)
                result = subprocess.run([FISH, "-i", "-c", '''
functions -q z zi; or exit 1
z "$FISH_TEST_DEST"; or exit 1
test "$PWD" = "$FISH_TEST_DEST"; or exit 1
fish_prompt
'''], env=self.env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected_prompt, result.stdout)


if __name__ == "__main__":
    unittest.main()
