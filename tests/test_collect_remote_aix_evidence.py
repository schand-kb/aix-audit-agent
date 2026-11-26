import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "collect_remote_aix_evidence.py"
spec = importlib.util.spec_from_file_location("aix_wrapper", SCRIPT)
wrapper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wrapper)


def complete_evidence(host="db2test", mode="unprivileged"):
    lines = [
        "AIX read-only audit evidence",
        "Collector version: 1.5",
        "Collection start UTC: 2026-11-27T00:00:00Z",
        "Evidence output mode: stdout",
        f"Privilege mode: {mode}",
    ]
    catalogue = list(wrapper.CATALOGUE_COMMANDS.items())
    for number in range(1, 46):
        name = "System hostname" if number == 1 else "Example"
        lines.append(f"Section {number}: {name}")
        if number == 1:
            lines.append(f"Observed hostname: {host}")
        if 20 <= number < 28:
            catalogue_id, command = catalogue[number - 20]
            lines.extend((
                f"Display command or skipped operation: {command}",
                f"Catalogue ID: {catalogue_id}",
                f"Execution mode: {mode}",
            ))
            if mode == "controlled-readonly":
                lines.append("Sudo executable: /usr/bin/sudo")
        lines.extend(("Command return code: 0", "Section status: COLLECTED"))
    lines.extend((
        "V1.5 extended total sections: 26",
        "V1.5 extended successful sections: 26",
        "V1.5 extended failed sections: 0",
        "V1.5 extended unavailable sections: 0",
        "V1.5 extended skipped sections: 0",
        "V1.5 extended not applicable sections: 0",
        "V1.5 extended classified sections: 26",
        "V1.5 extended counter invariant: 26 = 26 + 0 + 0 + 0 + 0",
        "V1 collection status: COMPLETE",
        "V1.5 extended collection status: COMPLETE",
        "UTC metadata status: COMPLETE",
        "Collection end UTC: 2026-11-27T00:00:00Z",
        "Overall collection status: COMPLETE",
    ))
    return "\n".join(lines) + "\n"


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.root.chmod(0o700)
        self.known_hosts = self.root / "known_hosts"
        self.known_hosts.write_text("test data\n")
        self.user_config = self.root / "user_config"
        self.user_config.write_text("Host db2test\n")
        self.args = [
            "--target", "db2test", "--user", "schand13",
            "--evidence-root", str(self.root),
            "--known-hosts", str(self.known_hosts),
        ]
        self.real_run = subprocess.run
        self.ssh_calls = []

    def invoke(self, args=None, ssh_result=0, output=None, syntax_result=0):
        if output is None:
            output = complete_evidence()

        def fake_run(command, **kwargs):
            if command[0] != wrapper.SSH:
                return self.real_run(command, **kwargs)
            if "-G" in command:
                host = command[-1]
                settings = (
                    f"hostname {host}\n"
                    "batchmode yes\nstricthostkeychecking true\nupdatehostkeys false\n"
                    "forwardagent no\nforwardx11 no\ncontrolmaster false\n"
                    "clearallforwardings yes\nnumberofpasswordprompts 0\n"
                    "permitlocalcommand no\npasswordauthentication no\n"
                    "kbdinteractiveauthentication no\n"
                )
                if host == "db2test":
                    settings += "user schand13\nproxyjump kbpdunixmgt\n"
                return subprocess.CompletedProcess(command, 0, stdout=settings, stderr="")
            self.ssh_calls.append(command)
            self.assertEqual(kwargs["stdin"].read(), wrapper.COLLECTOR.read_bytes())
            if command[-1] == "/usr/bin/ksh -n":
                if syntax_result:
                    kwargs["stderr"].write(b"simulated preflight failure\n")
                return subprocess.CompletedProcess(command, syntax_result)
            kwargs["stdout"].write(output.encode())
            kwargs["stderr"].write(b"simulated SSH diagnostic\n")
            if isinstance(ssh_result, OSError):
                raise ssh_result
            return subprocess.CompletedProcess(command, ssh_result)

        with mock.patch.object(wrapper, "USER_SSH_CONFIG", self.user_config), \
             mock.patch.object(wrapper.subprocess, "run", side_effect=fake_run):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return wrapper.main(self.args if args is None else args)

    def collection(self):
        dirs = [p for p in self.root.iterdir() if p.is_dir()]
        self.assertEqual(len(dirs), 1)
        directory = dirs[0]
        return directory, json.loads((directory / "manifest.json").read_text())

    def test_pilot_source_includes_ntpq_and_excludes_lsmpio(self):
        source = wrapper.COLLECTOR.read_text()
        self.assertIn("run_fixed_section 'NTP service status' 'lssrc -s xntpd' lssrc -s xntpd", source)
        self.assertIn("ntp_output=$(ntpq -pn </dev/null 2>&4)", source)
        self.assertIn("No usable NTP peer row was found.", source)
        self.assertNotRegex(source, r"(?m)^\s*lsmpio(?:\s|$)")

    def test_ntp_peer_row_parser_with_synthetic_data(self):
        source = wrapper.COLLECTOR.read_text()
        start = source.index("has_ntp_peer_row() {")
        end = source.index("\n}\n\nrun_fixed_section", start) + 2
        fragment = source[start:end]
        cases = (
            ("", False),
            ("remote refid st t when poll reach delay offset jitter\n", False),
            ("*192.0.2.1 .GPS. 2 u 4 64 377 0.1 0.2 0.3\n", True),
            (" 192.0.2.2 .GPS. 2 u - 64 0 0.1 0.2 0.3\n", True),
            ("unparseable peer output\n", False),
        )
        for sample, expected in cases:
            with self.subTest(sample=sample):
                result = self.real_run(
                    ["/bin/sh", "-c", fragment + '\nset -f\nhas_ntp_peer_row "$1"\n', "test", sample],
                    stdin=subprocess.DEVNULL, capture_output=True, check=False,
                )
                self.assertEqual(result.returncode == 0, expected)

    def test_missing_arguments(self):
        for args in ([], self.args[2:], self.args[:4] + self.args[6:]):
            with self.subTest(args=args), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.invoke(args)
        self.assertFalse(self.ssh_calls)

    def test_invalid_hosts(self):
        for target in ("", "-option", "a..b", "host;id", "host$(id)", "bad host", "a" * 64):
            args = self.args.copy()
            args[1] = target
            with self.subTest(target=target), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.invoke(args)
        self.assertFalse(self.ssh_calls)

    def test_valid_but_unauthorized_destination_and_account(self):
        for index, value in ((1, "other-host"), (3, "other-user")):
            args = self.args.copy()
            args[index] = value
            with self.subTest(value=value), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.invoke(args)
        self.assertFalse(self.ssh_calls)

    def test_unreviewed_ssh_directive_fails_without_connection(self):
        self.user_config.write_text("Match exec arbitrary-command\n")
        self.assertEqual(self.invoke(), 1)
        _, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "FAILED")
        self.assertFalse(self.ssh_calls)

    def test_prohibited_repositories(self):
        for repo in wrapper.PROHIBITED:
            args = self.args.copy()
            args[5] = str(repo)
            with self.subTest(repo=repo):
                self.assertEqual(self.invoke(args), 2)
        self.assertFalse(self.ssh_calls)

    def test_other_git_worktree(self):
        repo = self.root / "another"
        repo.mkdir(mode=0o700)
        self.real_run([wrapper.GIT, "init", "-q", str(repo)], check=True)
        args = self.args.copy()
        args[5] = str(repo)
        self.assertEqual(self.invoke(args), 2)
        self.assertFalse(self.ssh_calls)

    def test_symlink_to_git_worktree(self):
        link = self.root / "repository-link"
        link.symlink_to(wrapper.PROHIBITED[0], target_is_directory=True)
        args = self.args.copy()
        args[5] = str(link)
        self.assertEqual(self.invoke(args), 2)
        self.assertFalse(self.ssh_calls)

    def test_missing_root_and_collector(self):
        args = self.args.copy()
        args[5] = str(self.root / "missing")
        self.assertEqual(self.invoke(args), 2)
        args[5] = ""
        self.assertEqual(self.invoke(args), 2)
        with mock.patch.object(wrapper, "COLLECTOR", self.root / "missing.ksh"):
            self.assertEqual(self.invoke(), 2)
        self.assertFalse(self.ssh_calls)

    def test_private_root_required(self):
        self.root.chmod(0o755)
        self.assertEqual(self.invoke(), 2)
        self.root.chmod(0o700)
        self.assertFalse(self.ssh_calls)

    def test_mocked_success_manifest_and_permissions(self):
        self.assertEqual(self.invoke(), 0)
        directory, manifest = self.collection()
        self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
        for filename in ("evidence.txt", "ssh-stderr.txt", "collector.ksh", "manifest.json", "transport-ssh.conf"):
            self.assertEqual(stat.S_IMODE((directory / filename).stat().st_mode), 0o600)
        self.assertEqual(manifest["overall_status"], "COMPLETE")
        self.assertEqual(manifest["privilege_mode"], "unprivileged")
        self.assertEqual(manifest["observed_hostname"], "db2test")
        self.assertEqual(manifest["syntax_check_ssh_exit_status"], 0)
        self.assertEqual(manifest["ssh_exit_status"], 0)
        for field, filename in (
            ("collector_sha256", "collector.ksh"),
            ("evidence_sha256", "evidence.txt"),
            ("stderr_sha256", "ssh-stderr.txt"),
        ):
            self.assertEqual(manifest[field], hashlib.sha256((directory / filename).read_bytes()).hexdigest())
        self.assertNotIn(b"simulated SSH diagnostic", (directory / "evidence.txt").read_bytes())
        self.assertIn(b"simulated SSH diagnostic", (directory / "ssh-stderr.txt").read_bytes())
        self.assertEqual(len(self.ssh_calls), 2)
        self.assertEqual(self.ssh_calls[0][-1], "/usr/bin/ksh -n")
        command = self.ssh_calls[1]
        for option in ("BatchMode=yes", "ConnectTimeout=10", "StrictHostKeyChecking=yes",
                       "UpdateHostKeys=no", "ForwardAgent=no", "ClearAllForwardings=yes"):
            self.assertIn(option, command)
        self.assertEqual(command[-1], "/usr/bin/ksh -s -- --stdout")

    def test_explicit_privileged_mode_recorded_and_transmitted(self):
        output = complete_evidence(mode="controlled-readonly")
        self.assertEqual(self.invoke(self.args + ["--privileged-readonly"], output=output), 0)
        _, manifest = self.collection()
        self.assertEqual(manifest["privilege_mode"], "controlled-readonly")
        self.assertEqual(self.ssh_calls[1][-1], "/usr/bin/ksh -s -- --stdout --privileged-readonly")

    def test_failed_native_syntax_or_transport_stops_before_collection(self):
        self.assertEqual(self.invoke(syntax_result=255), 1)
        directory, manifest = self.collection()
        self.assertEqual(manifest["syntax_check_ssh_exit_status"], 255)
        self.assertIsNone(manifest["ssh_exit_status"])
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")
        self.assertEqual((directory / "evidence.txt").read_bytes(), b"")
        self.assertEqual(len(self.ssh_calls), 1)

    def test_mode_mismatch_or_missing_catalogue_is_incomplete(self):
        samples = (
            complete_evidence(),
            complete_evidence(mode="controlled-readonly").replace("Catalogue ID: AIX-BOOT-001", "Catalogue ID: OTHER"),
            complete_evidence(mode="controlled-readonly").replace("Catalogue ID: AIX-BOOT-003", "Catalogue ID: OTHER"),
            complete_evidence(mode="controlled-readonly").replace("/usr/bin/bootlist -m normal -o", "/usr/bin/bootlist -m normal"),
            complete_evidence(mode="controlled-readonly").replace("/usr/sbin/vmo -a", "/usr/sbin/vmo -o unsafe"),
        )
        for sample in samples:
            with self.subTest(sample=sample[:60]), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / "evidence"
                path.write_text(sample)
                self.assertFalse(wrapper.evidence_identity_and_status(path, "controlled-readonly")[1])

    def test_mocked_failure_retains_evidence(self):
        self.assertEqual(self.invoke(ssh_result=255, output="partial output\n"), 1)
        directory, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")
        self.assertEqual(manifest["ssh_exit_status"], 255)
        self.assertIsNone(manifest["observed_hostname"])
        self.assertEqual((directory / "evidence.txt").read_text(), "partial output\n")
        self.assertEqual(len(self.ssh_calls), 2)

    def test_mocked_ssh_launch_error_retains_manifest(self):
        self.assertEqual(self.invoke(ssh_result=OSError("simulated launch failure")), 1)
        directory, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")
        self.assertIsNone(manifest["ssh_exit_status"])
        self.assertIn(b"Unable to start SSH", (directory / "ssh-stderr.txt").read_bytes())
        self.assertEqual(len(self.ssh_calls), 2)

    def test_missing_final_marker_is_incomplete_even_with_zero_exit(self):
        self.assertEqual(self.invoke(output="AIX read-only audit evidence\n"), 1)
        _, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")

    def test_inconsistent_sections_are_incomplete(self):
        output = complete_evidence().replace("Section 12: Example\n", "")
        self.assertEqual(self.invoke(output=output), 1)
        _, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")

    def test_not_applicable_sections_are_accounted_for(self):
        output = complete_evidence()
        for number in (33, 34):
            output = output.replace(
                f"Section {number}: Example\nCommand return code: 0\nSection status: COLLECTED\n",
                f"Section {number}: Example\nSection status: NOT APPLICABLE\n",
            )
        output = output.replace("V1.5 extended successful sections: 26", "V1.5 extended successful sections: 24")
        output = output.replace("V1.5 extended not applicable sections: 0", "V1.5 extended not applicable sections: 2")
        output = output.replace(
            "V1.5 extended counter invariant: 26 = 26 + 0 + 0 + 0 + 0",
            "V1.5 extended counter invariant: 26 = 24 + 0 + 0 + 0 + 2",
        )
        self.assertEqual(self.invoke(output=output), 0)
        _, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "COMPLETE")

    def test_identity_mismatch_is_incomplete(self):
        output = complete_evidence("other-host")
        self.assertEqual(self.invoke(output=output), 1)
        _, manifest = self.collection()
        self.assertEqual(manifest["overall_status"], "INCOMPLETE")
        self.assertEqual(manifest["observed_hostname"], "other-host")


if __name__ == "__main__":
    unittest.main()
