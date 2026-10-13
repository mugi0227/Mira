"""Install the existing distribution identity; never create certificates in CI."""
import base64
import json
import os
from pathlib import Path
import plistlib
import secrets
import shlex
import subprocess
import tempfile
import time
import urllib.request

import jwt
import yaml


def main():
    config = json.loads(Path("ci/signing.json").read_text())
    password = os.environ["MIRA_SIGNING_PASSWORD"]
    keychain_password = secrets.token_urlsafe(32)

    def run(args):
        result = subprocess.run(args, text=True, capture_output=True)
        if result.returncode:
            message = result.stderr.replace(password, "***").replace(keychain_password, "***")
            raise RuntimeError(args[0] + " failed: " + message)
        return result.stdout

    now = int(time.time())
    token = jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        Path(os.environ["ASC_KEY_PATH"]).read_text(), algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )
    temp = Path(os.environ["RUNNER_TEMP"])
    keychain = temp / "mira-distribution.keychain-db"
    previous_keychains = shlex.split(run(["security", "list-keychains", "-d", "user"]))
    run(["security", "create-keychain", "-p", keychain_password, str(keychain)])
    with Path(os.environ["GITHUB_ENV"]).open("a") as output:
        output.write("MIRA_SIGNING_KEYCHAIN=" + str(keychain) + "\n")
    run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
    run(["security", "unlock-keychain", "-p", keychain_password, str(keychain)])
    with tempfile.NamedTemporaryFile(dir=temp, suffix=".p12", delete=False) as output:
        output.write(base64.b64decode(os.environ["MIRA_SIGNING_P12"], validate=True))
        p12_path = Path(output.name)
    try:
        run(["security", "import", str(p12_path), "-k", str(keychain), "-P", password,
             "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    finally:
        p12_path.unlink(missing_ok=True)
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
         "-s", "-k", keychain_password, str(keychain)])
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous_keychains])
    intermediate = temp / "AppleWWDRCAG3.cer"
    with urllib.request.urlopen("https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer", timeout=30) as response:
        intermediate.write_bytes(response.read())
    run(["security", "import", str(intermediate), "-k", str(keychain)])
    identities = run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain)])
    if config["fingerprintSha1"] not in identities:
        raise RuntimeError("The configured distribution signing identity is unavailable")

    project = yaml.safe_load(Path("project.yml").read_text())
    for target, identifier in [("Mira", "jp.mugi.mira"), ("MiraWidget", "jp.mugi.mira.widget")]:
        profile = config["profiles"][identifier]
        req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/profiles/" + profile["id"],
                                     headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(req, timeout=30) as response:
            attributes = json.load(response)["data"]["attributes"]
        if attributes["profileState"] != "ACTIVE" or attributes["profileType"] != "IOS_APP_STORE":
            raise RuntimeError("An active App Store profile is required for " + identifier)
        raw = base64.b64decode(attributes["profileContent"])
        profile_path = temp / (attributes["uuid"] + ".mobileprovision")
        profile_path.write_bytes(raw)
        decoded = plistlib.loads(run(["security", "cms", "-D", "-i", str(profile_path)]).encode())
        entitlements = decoded["Entitlements"]
        if entitlements["application-identifier"] != "572NVCGLGQ." + identifier:
            raise RuntimeError("Profile app identifier mismatch")
        if entitlements.get("get-task-allow") or entitlements.get("com.apple.security.application-groups") != ["group.jp.mugi.mira"]:
            raise RuntimeError("Profile must support App Store distribution and Mira's shared container")
        if identifier == "jp.mugi.mira" and entitlements.get("com.apple.developer.applesignin") != ["Default"]:
            raise RuntimeError("Sign in with Apple entitlement is missing")
        for directory in [Path.home() / "Library/MobileDevice/Provisioning Profiles",
                          Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"]:
            directory.mkdir(parents=True, exist_ok=True)
            (directory / profile_path.name).write_bytes(raw)
        project["targets"][target]["settings"]["base"].update({
            "CODE_SIGN_STYLE": "Manual",
            "CODE_SIGN_IDENTITY": config["fingerprintSha1"],
            "DEVELOPMENT_TEAM": "572NVCGLGQ",
            "PROVISIONING_PROFILE_SPECIFIER": attributes["name"],
        })
    # Only the runner's checkout receives these signing settings.
    Path("project.yml").write_text(yaml.safe_dump(project, allow_unicode=True, sort_keys=False))
    print("Reusable distribution identity and both App Store profiles verified")


if __name__ == "__main__":
    main()
