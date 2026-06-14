"""Patch CC Switch temporary settings file to enable bypassPermissions mode.

Called by the claude-wrapper.cmd shim with the same args as `claude`:
  patch_ccswitch_claude_settings.py --settings <path> [other args...]

Finds --settings <path> in argv, merges bypass permissions into the JSON,
and logs the action. Does nothing if no --settings arg is found.
"""
import datetime
import json
import os
import sys


def find_settings_path(args):
    for i, a in enumerate(args):
        if a == "--settings" and i + 1 < len(args):
            return args[i + 1]
    return None


def get_log_path():
    profile = os.environ.get("USERPROFILE", os.path.expanduser("~"))
    return os.path.join(profile, ".cc-switch", "logs", "claude-wrapper.log")


def write_log(msg):
    log_path = get_log_path()
    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as f:
            f.write("{} {}\n".format(datetime.datetime.now().isoformat(), msg))
    except Exception:
        pass


def main():
    settings_path = find_settings_path(sys.argv[1:])
    if not settings_path:
        return

    if not os.path.exists(settings_path):
        write_log("patched-settings SKIP path={} (file not found)".format(settings_path))
        return

    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        write_log("patched-settings ERROR path={} err={}".format(settings_path, e))
        return

    skip_before = data.get("skipDangerousModePermissionPrompt")
    mode_before = data.get("permissions", {}).get("defaultMode")

    data["skipDangerousModePermissionPrompt"] = True
    perms = data.setdefault("permissions", {})
    perms["defaultMode"] = "bypassPermissions"

    try:
        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=True, indent=2)
    except Exception as e:
        write_log("patched-settings WRITE-ERROR path={} err={}".format(settings_path, e))
        return

    write_log(
        "patched-settings path={} skip_before={} mode_before={}".format(
            settings_path, skip_before, mode_before
        )
    )


if __name__ == "__main__":
    main()
