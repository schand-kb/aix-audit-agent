import re
import subprocess
import tempfile
import unittest
from pathlib import Path


SOURCE = (Path(__file__).resolve().parents[1] / "scripts" / "aix_readonly_audit.ksh").read_text()


def function(name):
    match = re.search(r"(?ms)^" + re.escape(name) + r"\(\) \{\n.*?^\}", SOURCE)
    if match is None:
        raise AssertionError(f"Missing function {name}")
    return match.group()


class DispatcherTests(unittest.TestCase):
    def run_dispatch(self, arguments, sudo_status=0, sudo_path="fake_sudo"):
        script = """
        exec 4>&2
        write_v11_section_header() { :; }
        record_v11_executed_status() { printf 'RESULT:%s\\n' "$command_rc"; }
        record_v11_unavailable_status() { printf 'UNAVAILABLE\\n'; }
        fake_sudo() { printf 'ARG:%s\\n' "$@"; return "$fake_status"; }
        privilege_mode=controlled-readonly
        sudo_path=$1
        fake_status=$2
        shift 2
        """ + function("run_catalogue_section") + '\nrun_catalogue_section "$@"\n'
        return subprocess.run(
            ["/bin/bash", "-c", script, "test", sudo_path, str(sudo_status), *arguments],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
        )

    def test_only_exact_catalogue_vectors_reach_sudo(self):
        commands = {
            "AIX-BOOT-001": ("/usr/sbin/bootinfo", "-b"),
            "AIX-BOOT-003": ("/usr/bin/bootlist", "-m", "normal", "-o"),
            "AIX-DUMP-001": ("/usr/bin/sysdumpdev", "-l"),
            "AIX-SW-002": ("/usr/sbin/emgr", "-l"),
            "AIX-TUNE-002": ("/usr/sbin/vmo", "-a"),
            "AIX-TUNE-003": ("/usr/sbin/ioo", "-a"),
            "AIX-TUNE-004": ("/usr/sbin/schedo", "-a"),
            "AIX-OPS-002": ("/usr/lib/errdemon", "-l"),
        }
        for catalogue_id, command in commands.items():
            with self.subTest(catalogue_id=catalogue_id):
                result = self.run_dispatch([catalogue_id])
                self.assertEqual(result.returncode, 0)
                self.assertEqual(
                    [line[4:] for line in result.stdout.splitlines() if line.startswith("ARG:")],
                    ["-n", *command],
                )
                self.assertIn("Execution mode: controlled-readonly", result.stdout)
                self.assertIn("RESULT:0", result.stdout)

    def test_unknown_id_and_extra_argument_never_invoke_sudo(self):
        for arguments in (["UNKNOWN"], ["AIX-BOOT-001", "-s"], ["AIX-BOOT-003", "hdisk0"], []):
            with self.subTest(arguments=arguments):
                result = self.run_dispatch(arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("ARG:", result.stdout)

    def test_denial_and_missing_sudo_do_not_retry(self):
        denied = self.run_dispatch(["AIX-DUMP-001"], sudo_status=1)
        self.assertNotEqual(denied.returncode, 0)
        self.assertIn("RESULT:1", denied.stdout)
        self.assertEqual(denied.stdout.count("ARG:-n"), 1)
        missing = self.run_dispatch(["AIX-DUMP-001"], sudo_path="")
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("COMMAND NOT AVAILABLE", missing.stdout)
        self.assertNotIn("ARG:", missing.stdout)

    def test_only_closed_dispatcher_uses_sudo(self):
        self.assertEqual(SOURCE.count('"$sudo_path" -n "$@"'), 2)
        self.assertNotRegex(SOURCE, r"(?m)^\s*eval(?:\s|$)")
        self.assertNotRegex(SOURCE, r"(?m)^\s*(?:/usr/bin/)?lsmpio(?:\s|$)")


class LogicalVolumeTests(unittest.TestCase):
    def test_inventory_validation_and_global_cap(self):
        sample = (
            "rootvg:\n"
            "LV NAME TYPE LPs PPs PVs LV STATE MOUNT POINT\n"
            "hd4 jfs2 1 1 1 open/syncd /\n"
            "-bad jfs2 1 1 1 open/syncd /\n"
            "bad;exec jfs2 1 1 1 open/syncd /\n"
            "lv2 jfs2 2 2 1 closed/syncd /test\n"
            "lv3 jfs2 1 1 1 open/syncd /other\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            fake = Path(temporary) / "lslv"
            fake.write_text("#!/bin/sh\nprintf 'LV-CALL:%s\\n' \"$1\"\n")
            fake.chmod(0o700)
            script = """
            set -f
            LC_ALL=C
            export LC_ALL
            write_v11_section_header() { :; }
            record_v11_skipped() { printf 'SKIPPED:%s\\n' "$v11_section_name"; }
            record_v11_executed_status() { printf 'RESULT:%s\\n' "$command_rc"; }
            record_v11_unavailable_status() { printf 'UNAVAILABLE\\n'; }
            validated_vg=rootvg
            queried_lv_count=0
            v11_lv_cap=2
            lv_cap_recorded=0
            """ + function("is_safe_inventory_line") + "\n" + function("process_lv_inventory")
            script = script.replace("/usr/sbin/lslv", str(fake))
            script += '\nprocess_lv_inventory "$1"\n'
            result = subprocess.run(
                ["/bin/bash", "-c", script, "test", sample],
                stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
            )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(re.findall(r"^LV-CALL:(.*)$", result.stdout, re.MULTILINE), ["hd4", "lv2"])
        self.assertIn("Invalid logical volume row", result.stdout)
        self.assertIn("Logical volume enumeration cap reached", result.stdout)

    def test_unrecognized_header_never_queries_volumes(self):
        script = """
        set -f
        record_v11_skipped() { printf 'SKIPPED\\n'; }
        validated_vg=rootvg
        """ + function("is_safe_inventory_line") + "\n" + function("process_lv_inventory")
        script += '\nprocess_lv_inventory "$1"\n'
        result = subprocess.run(
            ["/bin/bash", "-c", script, "test", "unrecognized\nhd4 jfs2 1 1 1 open/syncd /"],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("SKIPPED", result.stdout)
        self.assertNotIn("Logical volume detail", result.stdout)


class CollectorIntegrationTests(unittest.TestCase):
    def run_collector(self, mode, bootlist_empty=False, hostname="db2test", sudo_fails=False,
                      operating_system="AIX", bootlist_sudo_fails=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake = root / "fake"
            fake.write_text("""#!/bin/sh
name=${0##*/}
case "$name" in
    date) case "$1" in -u) echo 2026-11-27T00:00:00Z ;; *) echo 20261127_000000 ;; esac ;;
    hostname) echo "$FAKE_HOSTNAME" ;;
    uname) if [ "$1" = -s ]; then echo "$FAKE_OS"; else echo synthetic; fi ;;
    lsvg) case "$1" in
        -o) echo rootvg ;;
        -l) printf 'rootvg:\\nLV NAME TYPE LPs PPs PVs LV STATE MOUNT POINT\\nhd4 jfs2 1 1 1 open/syncd /\\n' ;;
        *) echo synthetic ;;
        esac ;;
    lspv) if [ "$#" -eq 0 ]; then echo 'hdisk0 0000000000000001 rootvg active'; else echo synthetic; fi ;;
    lsdev) if [ "$2" = disk ]; then echo 'hdisk0 Available 00 Disk'; else echo 'fcs0 Available 00 Fibre Channel Adapter'; fi ;;
    ntpq) echo '*192.0.2.1 .GPS. 2 u 4 64 377 0.1 0.2 0.3' ;;
    bootlist) printf 'MOCK-DIRECT-BOOTLIST\\n' >&2; if [ "$EMPTY_BOOTLIST" != 1 ]; then echo hdisk0; fi ;;
    sudo)
        printf 'MOCK-SUDO:' >&2; printf ' %s' "$@" >&2; printf '\\n' >&2
        if [ "$2" = "$FAKE_BOOTLIST" ]; then
            if [ "$FAIL_BOOTLIST" = 1 ]; then exit 1; fi
            if [ "$EMPTY_BOOTLIST" != 1 ]; then echo hdisk0; fi
        fi
        [ "$FAIL_SUDO" != 1 ]
        ;;
    *) echo synthetic ;;
esac
""")
            fake.chmod(0o700)
            names = (
                "date hostname uname oslevel prtconf lparstat vmstat svmon lsps df lsfs "
                "lsvg lspv lsdev lspath netstat errpt lssrc lsattr lscfg mount who cat "
                "ntpq lslpp no vmo ioo schedo nfso lslv ifconfig bootinfo sysdumpdev emgr "
                "errdemon bootlist sudo"
            ).split()
            for name in names:
                (root / name).symlink_to(fake)
            script = SOURCE.replace("PATH=/usr/bin:/usr/sbin:/sbin", f"PATH={root}")
            for prefix in ("/usr/bin/", "/usr/sbin/", "/usr/lib/", "/opt/freeware/bin/"):
                script = script.replace(prefix, str(root) + "/")
            script_path = root / "collector"
            script_path.write_text(script)
            arguments = ["/bin/bash", str(script_path), "--stdout"]
            if mode == "controlled-readonly":
                arguments.append("--privileged-readonly")
            return subprocess.run(
                arguments, stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
                env={
                    "FAKE_HOSTNAME": hostname,
                    "EMPTY_BOOTLIST": "1" if bootlist_empty else "0",
                    "FAIL_SUDO": "1" if sudo_fails else "0",
                    "FAKE_OS": operating_system,
                    "FAKE_BOOTLIST": str(root / "bootlist"),
                    "FAIL_BOOTLIST": "1" if bootlist_sudo_fails else "0",
                },
            )

    def test_complete_modes_with_mocked_utilities(self):
        for mode, sudo_calls in (("unprivileged", 0), ("controlled-readonly", 8)):
            with self.subTest(mode=mode):
                result = self.run_collector(mode)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn(f"Privilege mode: {mode}", result.stdout)
                self.assertIn("Section status: COLLECTED", result.stdout)
                self.assertIn(": Logical volume detail", result.stdout)
                self.assertIn("Overall collection status: COMPLETE", result.stdout)
                self.assertEqual(result.stdout.count("MOCK-SUDO:"), sudo_calls)
                self.assertEqual(result.stdout.count("MOCK-DIRECT-BOOTLIST"), mode == "unprivileged")
                if mode == "controlled-readonly":
                    self.assertRegex(result.stdout, r"MOCK-SUDO: -n .*/bootlist -m normal -o")

    def test_empty_bootlist_is_incomplete(self):
        for mode in ("unprivileged", "controlled-readonly"):
            with self.subTest(mode=mode):
                result = self.run_collector(mode, bootlist_empty=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Empty boot list output is inconclusive.", result.stdout)
                self.assertIn("Overall collection status: INCOMPLETE", result.stdout)
                if mode == "controlled-readonly":
                    self.assertEqual(result.stdout.count("MOCK-SUDO:"), 8)
                    self.assertNotIn("MOCK-DIRECT-BOOTLIST", result.stdout)

    def test_denied_privileged_bootlist_stops_without_unprivileged_retry(self):
        result = self.run_collector("controlled-readonly", bootlist_sudo_fails=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Privileged collection stopped after sudo command failure.", result.stdout)
        self.assertNotIn("MOCK-DIRECT-BOOTLIST", result.stdout)
        self.assertNotIn("Catalogue ID: AIX-TUNE-002", result.stdout)

    def test_wrong_host_refuses_privileged_mode_before_sudo(self):
        result = self.run_collector("controlled-readonly", hostname="other-host")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Privileged collection refused", result.stdout)
        self.assertNotIn("MOCK-SUDO:", result.stdout)

    def test_sudo_failure_is_incomplete_without_retry(self):
        result = self.run_collector("controlled-readonly", sudo_fails=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count("MOCK-SUDO:"), 1)
        self.assertEqual(result.stdout.count("Section status: FAILED"), 1)
        self.assertIn("Privileged collection stopped after sudo command failure.", result.stdout)

    def test_non_aix_refuses_privileged_mode_before_collection(self):
        result = self.run_collector("controlled-readonly", operating_system="Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("operating system is not confirmed as AIX", result.stderr)
        self.assertNotIn("MOCK-SUDO:", result.stdout)


if __name__ == "__main__":
    unittest.main()
