#!/usr/bin/env python3
"""Export and verify the experimental Android ARM64 APK, separately from Quest.

Requires the Android Experimental preset, Godot 4.7.2 with configured SDK/JDK,
Android SDK build-tools, and GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}.
Private signing material stays outside the repository. Does not upload or install.
"""
from __future__ import annotations

import argparse
import configparser
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_release
import tool_banner

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.b0realis.shandalar.android"
PRESET = "Android Experimental"
PERMISSIONS = {"android.permission." + name for name in (
    "INTERNET", "ACCESS_NETWORK_STATE", "ACCESS_WIFI_STATE", "CHANGE_WIFI_MULTICAST_STATE")}


def version_code(version: str) -> int:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a three-component game version")
    major, minor, patch = map(int, version.split("."))
    code = major * 1_000_000 + minor * 1_000 + patch
    if minor >= 1000 or patch >= 1000 or not 0 < code <= 2_100_000_000:
        raise ValueError("Version cannot be encoded as an Android update code")
    return code


def check_preset(root: Path, version: str) -> None:
    cfg = configparser.ConfigParser(interpolation=None)
    # Godot permits unindented multiline strings in other platforms' SSH
    # scripts, which are not INI. Parse only this target's two sections.
    text = (root / "export_presets.cfg").read_text(encoding="utf-8")
    blocks = re.findall(r"(?ms)^\[([^\]]+)\]\n(.*?)(?=^\[|\Z)", text)
    matches = [name for name, body in blocks
               if re.search(r'^name="' + PRESET + r'"$', body, re.M)]
    if len(matches) != 1:
        raise ValueError("Expected exactly one Android Experimental preset")
    cfg.read_string("\n".join(f"[{name}]\n{body}" for name, body in blocks
                              if name in (matches[0], matches[0] + ".options")))
    sections = [s for s in cfg.sections() if cfg[s].get("name") == f'"{PRESET}"']
    if len(sections) != 1:
        raise ValueError("Install the Android Experimental preset from packaging/android/export-preset.cfg")
    section = sections[0]
    if cfg[section].get("custom_features", '""') != '""':
        raise ValueError("No test/custom features allowed in a public Android export")
    if section + ".options" not in cfg:
        raise ValueError("Android Experimental preset is missing its options section")
    opts = cfg[section + ".options"]
    expected = {"package/unique_name": f'"{PACKAGE}"', "package/signed": "true",
                "version/code": str(version_code(version)), "version/name": '""',
                "architectures/arm64-v8a": "true", "architectures/armeabi-v7a": "false",
                "architectures/x86": "false", "architectures/x86_64": "false",
                "xr_features/xr_mode": "0", "command_line/extra_args": '""'}
    for key, value in expected.items():
        if opts.get(key) != value:
            raise ValueError(f"Android preset must set {key}={value}")


def run(args: list[str], **kwargs) -> str:
    result = subprocess.run(list(map(str, args)), check=True, stdin=subprocess.DEVNULL,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=120, **kwargs)
    return result.stdout


def check_elf(data: bytes) -> None:
    """ARM64 ELF64, little endian, with 16 KiB-compatible LOAD segments."""
    if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 183:
        raise ValueError("Expected an ARM64 ELF64 library")
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    if size < 56 or not count or offset + size * count > len(data):
        raise ValueError("Invalid ELF program headers")
    loads = 0
    for i in range(count):
        pos = offset + i * size
        if struct.unpack_from("<I", data, pos)[0] != 1:
            continue
        loads += 1
        file_offset, address = struct.unpack_from("<QQ", data, pos + 8)
        alignment = struct.unpack_from("<Q", data, pos + 48)[0]
        if alignment < 16384 or (address - file_offset) % 16384:
            raise ValueError("Native library is not 16 KiB-page compatible")
    if not loads:
        raise ValueError("ELF contains no loadable segments")


def verify(apk: Path, sdk: Path, version: str, build_tools: str) -> None:
    directory = sdk / "build-tools" / build_tools
    for name in ("aapt", "apksigner", "zipalign"):
        if not (directory / name).is_file():
            raise ValueError(f"Missing SDK build-tools {build_tools}: {name}")
    badging = run([directory / "aapt", "dump", "badging", apk])
    match = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not match or match.groups() != (PACKAGE, str(version_code(version)), version):
        raise ValueError("APK identity/version does not match this Android release")
    if "application-debuggable" in badging:
        raise ValueError("APK must be non-debuggable")
    # aapt's old badging printer omits activity-alias launchers (Godot 4.7).
    # Inspect the exported MAIN/LAUNCHER alias, not just that printed field.
    manifest = run([directory / "aapt", "dump", "xmltree", apk, "AndroidManifest.xml"])
    aliases = re.findall(r"(?ms)^      E: activity-alias .*?(?=^      E:|\Z)", manifest)
    if "launchable-activity:" not in badging and not any(
            'android.intent.action.MAIN' in alias and 'android.intent.category.LAUNCHER' in alias
            and re.search(r'android:exported[^\n]+=\(type 0x12\)0xffffffff', alias)
            for alias in aliases):
        raise ValueError("APK has no exported launcher activity or alias")
    if "native-code: 'arm64-v8a'" not in badging:
        raise ValueError("APK must declare ARM64")
    permissions = set(re.findall(r"uses-permission: name='([^']+)'", badging))
    if permissions != PERMISSIONS:
        raise ValueError(f"Unexpected APK permissions: {sorted(permissions ^ PERMISSIONS)}")
    signature = run([directory / "apksigner", "verify", "--verbose", "--print-certs", apk])
    if not re.search(r"^Signer #1 certificate DN: CN=b0realis$", signature, re.M):
        raise ValueError("APK signing certificate must use the public pseudonym only")
    run([directory / "zipalign", "-c", "-P", "16", "4", apk])
    with zipfile.ZipFile(apk) as archive:
        libraries = [n for n in archive.namelist() if n.startswith("lib/") and n.endswith(".so")]
        if not libraries or any(not n.startswith("lib/arm64-v8a/") for n in libraries):
            raise ValueError("APK has missing or non-ARM64 native libraries")
        if any("override.cfg" in n for n in archive.namelist()):
            raise ValueError("APK contains a test override")
        for name in libraries:
            check_elf(archive.read(name))
        if archive.testzip():
            raise ValueError("APK ZIP integrity check failed")
    package_release.guard_private([apk])
    print("Verified: signed release APK, ARM64, 16 KiB alignment, network-only permissions, privacy guard.")
    for line in badging.splitlines():
        if line.startswith(("package:", "sdkVersion:", "targetSdkVersion:")):
            print(line)
    for line in signature.splitlines():
        if line.startswith("Signer #1 certificate SHA-256 digest:"):
            print(line)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, epilog=tool_banner.BANNER_HELP,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    tool_banner.add_version_flag(parser, "build_android.py", __file__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--build-tools", default="36.0.0")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    tool_banner.show(("SHANDALAR ANDROID",), ("Experimental ARM64 export",), __file__)
    try:
        version = tool_banner.project_version(ROOT)
        if version is None:
            raise ValueError("Cannot read the game version from project.godot")
        apk = args.out.resolve() / "Shandalar.apk"
        if not args.verify_only:
            check_preset(ROOT, version)
            if os.environ.get("GODOT_EDITOR_CUSTOM_FEATURES"):
                raise ValueError("Unset GODOT_EDITOR_CUSTOM_FEATURES before exporting")
            for suffix in ("PATH", "USER", "PASSWORD"):
                if not os.environ.get("GODOT_ANDROID_KEYSTORE_RELEASE_" + suffix):
                    raise ValueError("Release signing environment is incomplete")
            if apk.exists():
                raise ValueError("Refusing to overwrite an existing APK; use a new output folder")
            godot = shutil.which(args.godot)
            if not godot or not run([godot, "--version"]).startswith("4.7.2.stable"):
                raise ValueError("Godot 4.7.2 is required")
            timeout = shutil.which("gtimeout") or shutil.which("timeout")
            if not timeout:
                raise ValueError("GNU timeout/gtimeout is required")
            apk.parent.mkdir(parents=True, exist_ok=True)
            log = apk.parent / "export.log"
            with log.open("w") as stream:
                result = subprocess.run([timeout, "-k", "5", "1800", godot, "--headless",
                                         "--path", str(ROOT), "--export-release", PRESET, str(apk)],
                                        stdin=subprocess.DEVNULL, stdout=stream, stderr=subprocess.STDOUT,
                                        timeout=1810)
            if result.returncode or re.search(r"(?:SCRIPT )?ERROR:", log.read_text()):
                raise ValueError("Android export failed; inspect export.log")
        verify(apk, args.sdk.resolve(), version, args.build_tools)
        return 0
    except (ValueError, OSError, configparser.Error, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(f"Android build refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
