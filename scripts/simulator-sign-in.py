#!/usr/bin/env python3
"""Signs the simulator's app in to a local OpenDiving server, with nothing tapped.

Asks the server for a sign-in code as the app does, reads the code from the server's log, where
a server with no mail transport writes it, redeems it, and launches the app pointed at that
server with the session the code started. Only a simulator build reads those launch arguments.

The server is the Docker container publishing the origin's port. The simulator is the one
`scripts/simulator.sh` prints unless `--device` names another, and the app is installed on it
from `.build` when it is not there yet.
"""

import argparse
import http.cookies
import json
import os
import plistlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.realpath(os.path.join(os.path.dirname(__file__), ".."))
APP = os.path.join(ROOT, ".build/Build/Products/Debug-iphonesimulator/OpenDiving.app")
EMAIL_VARIABLE = "OPENDIVING_SIGN_IN_EMAIL"


def stop(message):
    sys.exit(f"simulator-sign-in.py: {message}")


def run(*command):
    return subprocess.run(command, capture_output=True, text=True)


def post(origin, path, body):
    request = urllib.request.Request(
        f"{origin}/api/v1/{path}",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "opendiving-ios simulator-sign-in",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response), response.headers
    except urllib.error.HTTPError as error:
        try:
            detail = json.load(error).get("detail")
        except ValueError:
            detail = None
        stop(f"POST {path} answered {error.code}: {detail or error.reason}")
    except urllib.error.URLError as error:
        stop(f"no server at {origin}: {error.reason}")


def server_container(origin):
    parts = urllib.parse.urlsplit(origin)
    port = parts.port or (443 if parts.scheme == "https" else 80)
    listed = run("docker", "ps", "--filter", f"publish={port}", "--format", "{{.Names}}")
    names = listed.stdout.split()
    if listed.returncode != 0 or len(names) != 1:
        stop(
            f"expected one Docker container publishing port {port}, found "
            f"{', '.join(names) or 'none'}; name the server's with --container"
        )
    return names[0]


def code_from_log(container, email, since):
    """The newest code the server logged for `email` since the request, waiting out the log."""
    logged = re.compile(r"magic link for (\S+): \S+ \(code (\d{6})\)")
    for _ in range(20):
        log = run("docker", "logs", "--since", str(since), container)
        codes = [
            code
            for address, code in logged.findall(log.stdout + log.stderr)
            if address.lower() == email.lower()
        ]
        if codes:
            return codes[-1]
        time.sleep(0.25)
    stop(
        f"{container} logged no sign-in code for {email}: it logs one only while it has no mail "
        "transport (SMTP_HOST unset)"
    )


def simulator(device):
    if device:
        return device
    printed = subprocess.run(
        [os.path.join(ROOT, "scripts/simulator.sh")], stdout=subprocess.PIPE, text=True
    )
    if printed.returncode != 0:
        stop("scripts/simulator.sh printed no simulator")
    return printed.stdout.strip()


def bundle_id():
    """The built app's, which a `Signing.local.xcconfig` can change; the project's without one."""
    try:
        with open(os.path.join(APP, "Info.plist"), "rb") as file:
            return plistlib.load(file)["CFBundleIdentifier"]
    except OSError:
        return "app.opendiving.ios"


def install_if_missing(udid, bundle):
    booted = run("xcrun", "simctl", "bootstatus", udid, "-b")
    if booted.returncode != 0:
        stop(f"simulator {udid} did not boot: {booted.stderr.strip()}")
    if run("xcrun", "simctl", "get_app_container", udid, bundle).returncode == 0:
        return
    if not os.path.isdir(APP):
        stop(f"the app is not on simulator {udid} and not built at {APP}; build it first")
    installed = run("xcrun", "simctl", "install", udid, APP)
    if installed.returncode != 0:
        stop(f"could not install the app: {installed.stderr.strip()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "email",
        nargs="?",
        default=os.environ.get(EMAIL_VARIABLE),
        help=f"an account on the server; ${EMAIL_VARIABLE} when left out",
    )
    parser.add_argument("--server", default="http://localhost:8000", help="the server's origin")
    parser.add_argument("--device", help="a simulator's UDID, instead of this checkout's own")
    parser.add_argument(
        "--container", help="the server's Docker container, when its port does not say"
    )
    args = parser.parse_args()
    if not args.email:
        parser.error(f"give an account's email, or set {EMAIL_VARIABLE}")

    origin = args.server.rstrip("/")
    container = args.container or server_container(origin)
    udid = simulator(args.device)
    bundle = bundle_id()
    install_if_missing(udid, bundle)

    # A second early, for a container whose clock runs behind this one.
    since = int(time.time()) - 1
    asked, _ = post(origin, "auth/email/request", {"email": args.email})
    code = code_from_log(container, args.email, since)
    outcome, headers = post(
        origin,
        "auth/email/verify-code",
        {"request_id": asked["request_id"], "code": code, "idle_timeout": "extended"},
    )
    if outcome.get("status") != "authenticated":
        stop(f"{args.email} is {outcome.get('status')} on {origin}; finish that in the app")
    cookies = http.cookies.SimpleCookie()
    for header in headers.get_all("Set-Cookie") or []:
        cookies.load(header)
    if "refresh_token" not in cookies:
        stop("the server started a session but set no refresh_token cookie")

    launched = run(
        "xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle,
        "--server", origin, "--refresh-token", cookies["refresh_token"].value,
    )  # fmt: skip
    if launched.returncode != 0:
        stop(f"could not launch the app: {launched.stderr.strip()}")
    print(f"Signed in as {args.email} on {origin}, simulator {udid}")


if __name__ == "__main__":
    main()
