#!/usr/bin/env python3
"""Builds the app and installs it on a physical iPhone, asking which when more than one is paired.

Pressing return takes the first device listed, and `--first` takes it without asking. Simulators
are skipped, and the script stops when no physical device is known to the Mac.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.realpath(os.path.join(os.path.dirname(__file__), ".."))
APP = os.path.join(ROOT, ".build/Build/Products/Debug-iphoneos/OpenDiving.app")


def physical_devices():
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "devices.json")
        subprocess.run(
            ["xcrun", "devicectl", "list", "devices", "--json-output", out],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        with open(out) as f:
            devices = json.load(f)["result"]["devices"]

    found = []
    for device in devices:
        hardware = device["properties"]["hardware"]
        if hardware.get("reality") != "physical" or hardware.get("platform") != "iOS":
            continue
        # `deviceProperties` is deprecated, but the replacement carries no user-given name.
        name = device.get("deviceProperties", {}).get("name") or hardware["marketingName"]
        state = device["properties"]["connection"]["pairingState"]
        found.append((name, hardware["marketingName"], hardware["udid"], state))
    return found


def choose(devices):
    print("Physical devices:")
    for number, (name, model, udid, state) in enumerate(devices, 1):
        print(f"  {number}) {name} - {model}, {state} ({udid})")
    while True:
        answer = input(f"Install on [1-{len(devices)}, return for 1]: ").strip()
        if answer == "":
            return devices[0]
        if answer.isdigit() and 1 <= int(answer) <= len(devices):
            return devices[int(answer) - 1]
        print(f"Enter a number from 1 to {len(devices)}.")


def run(command):
    print("+", " ".join(command), flush=True)
    subprocess.run(command, check=True, cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--first",
        action="store_true",
        help="install on the first device listed without asking, for runs with no terminal",
    )
    args = parser.parse_args()

    devices = physical_devices()
    if not devices:
        print(
            "install-on-device.py: no physical device found. Connect the phone, unlock it and "
            "trust this Mac (see CONTRIBUTING.md, Running on your iPhone).",
            file=sys.stderr,
        )
        return 1

    _, _, udid, _ = devices[0] if args.first else choose(devices)

    run(["xcodegen", "generate"])
    run(
        [
            "xcodebuild", "build",
            "-project", "OpenDiving.xcodeproj",
            "-scheme", "OpenDiving",
            "-destination", f"id={udid}",
            "-derivedDataPath", ".build",
            "-allowProvisioningUpdates",
        ]
    )  # fmt: skip
    run(["xcrun", "devicectl", "device", "install", "app", "--device", udid, APP])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, EOFError):
        sys.exit(130)
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
